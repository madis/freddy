q = require 'q'
_ = require 'underscore'

#Encapsulate the request-response types of messaging
class Request

  RESPONSE_QUEUE_OPTIONS =
    queue:
      exclusive: true

  constructor: (@connection, @logger) ->
    @requests = {}
    @responseQueue = null

  prepare: (@consumer, @producer) ->
    q.reject('Need consumer and producer') unless @consumer and @producer
    @connection.createChannel().then (channel) =>
      @_setupResponseQueue(channel)
    .then =>
      @logger.debug "Created response queue for requests"
      q(this)

  deliverWithAckAndOptions: (destination, message, options, callback) =>
    @_request destination, message, options, (message, msgHandler) =>
      callback message.error if (typeof callback is 'function')

  deliverWithResponseAndOptions: (destination, message, options, callback) =>
    @_request destination, message, options, (message, msgHandler) =>
      callback message, msgHandler if (typeof callback is 'function')

  _request: (destination, message, options, callback) ->
    correlationId = @_uuid()
    @requests[correlationId] = {
      timeout: @_timeout(destination, message, options.timeout, correlationId, callback)
      callback: callback
    }
    _.extend options, {correlationId: correlationId, replyTo: @responseQueue}
    @producer.produce destination, message, options

  respondTo: (destination, callback) =>
    @consumer.consume destination, (message, msgHandler) =>
      properties = msgHandler.properties
      @_responder(properties) message, msgHandler, callback, (response) =>
        @producer.produce properties.replyTo, response, {correlationId: properties.correlationId} if response?

  _responder: (properties) ->
    if properties.headers?['message_with_ack']
      responder = @_respondToAck
    else if properties.correlationId
      responder = @_respondToRequest
    else
      responder = @_respondToSimpleDeliver

  _respondToAck: (message, msgHandler, callback, done) ->
    msgHandler.whenResponded.then (response) =>
      done(error: false)
    , (error) =>
      done(error: error)
    callback(message, msgHandler)

  _respondToRequest: (message, msgHandler, callback, done) ->
    msgHandler.whenResponded.then (response) =>
      done(response)
    , (error) =>
      done(error: error)
    callback(message, msgHandler)

  _respondToSimpleDeliver: (message, msgHandler, callback) ->
    callback(message, msgHandler)
    return null #avoid returning anything

  _uuid: ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
      r = Math.random() * 16 | 0
      v = if c is 'x' then r else (r & 0x3|0x8)
      v.toString(16)
    )

  _timeout: (destination, message, timeoutSeconds, correlationId, callback) ->
    setTimeout(
      =>
        @logger.info "Timeout waiting for response from #{destination} with #{timeoutSeconds}s, payload:", message
        delete @requests[correlationId]
        callback {error: "Timeout waiting for response"} if (typeof callback is 'function')
      , timeoutSeconds * 1000
      )

  _setupResponseQueue: (channel) =>
    @consumer.consumeWithOptions '', RESPONSE_QUEUE_OPTIONS, (message, msgHandler) =>
      correlationId = msgHandler.properties.correlationId
      if @requests[correlationId]?
        entry = @requests[correlationId]
        clearTimeout entry.timeout
        delete @requests[correlationId]
        @logger.debug "Received request response on #{@responseQueue}"
        entry.callback message, msgHandler
    .then (subscription) =>
      @responseQueue = subscription.queue

module.exports = Request