class Buffer extends Backbone.Model
  idAttribute: 'bid'

  @EVENT_TEXTS =
    'socket_closed':      'Disconnected'
    'connecting':         'Connecting'
    'connected':          'Connected to {{hostname}}'
    'quit_server':        'Quit server'
    'notice':             '{{msg}}'
    'you_nickchange':     'You are now known as {{newnick}}'
    'banned':             'You were banned'
    'connecting_retry':   'Retrying connection in {{interval}} seconds'
    'waiting_to_retry':   'Reconnecting in {{interval}} seconds'
    'connecting_failed':  'Failed to connect'
    'joining':            'Joining {{channels}}'
    'user_mode':          'Your mode is +{{newmode}}'
    'joined_channel':     '{{nick}} has joined'
    'parted_channel':     '{{nick}} has left'
    'quit':               '{{nick}} has quit'
    'away':               '{{nick}} is away'
    'kicked_channel':     '{{nick}} was kicked from {{chan}} by {{kicker}}: {{msg}}'
    'you_joined_channel': 'You have joined'
    'you_parted_channel': 'You have left'
    'channel_mode_is':    'Mode is: {{newmode}}'
    'channel_timestamp':  'Created at: {{timestamp}}'
    'nickchange':         '{{oldnick}} is now known as {{newnick}}'
    'user_channel_mode':  'Mode {{diff}} {{nick}} by {{from}}'
    'channel_url':        'Channel URL: {{url}}'
    'channel_topic':      '{{author}} set the topic: {{topic}}'
    'channel_mode':       'Channel mode: {{diff}} by {{from}}'

  constructor: (@connection, attrs) ->
    super(attrs)
    @backlog = new BufferEventList()
    @lastEid = 0
    @lastSeenEid = 0
    @reload(attrs)

  say: (text, callback) ->
    @connection.say(@get('name'), text, callback)

  markAllRead: ->
    if @backlog.length > 0
      @markRead(@backlog.last().items.last().get('eid'))

  markRead: (eid) ->
    return if eid < @lastEid
    @lastSeenEid = eid
    @set('unread', false)
    @set('highlights', 0)

  archive: ->
    @connection.post
      _method: 'archive-buffer'
      id: @id

  unarchive: ->
    @connection.post
      _method: 'unarchive-buffer'
      id: @id

  delete: ->
    @connection.post
      _method: 'delete-buffer'
      id: @id

  reload: (message) ->
    @exists = true
    for name in ['name', 'archived']
      @set(name, message[name])
    @lastSeenEid = message['last_seen_eid'] || 0
    @set('highlights', 0)

  clientDisconnected: ->
    @exists = false

  processMessage: (message) ->
    eid = message.eid
    type = message.type

    if eid > @lastEid
      @lastEid = eid

    if eid > 0 and @shouldRenderMessage(message)
      lastEvent = @backlog.last()
      item = new BufferEventItem(message)
      if lastEvent? and lastEvent.shouldMerge(item)
        lastEvent.items.add(item)
      else
        @backlog.add(new BufferEvent(item))

      if eid > @lastSeenEid
        if @hasFocus() || message.self
          @markRead(eid)
        else
          if _.contains(["buffer_msg", "buffer_me_msg", "notice"], message.type)
            @set('unread', true)
          if message.highlight
            @set('highlights', @get('highlights') + 1)

    if (!message.is_backlog) and (!@connection.isBacklog)
      if handler = @initializedMessageHandlers[type]
        handler.apply(this, [message])

    if handler = @messageHandlers[type]
      handler.apply(this, [message])

  hasFocus: ->
    # FIXME
    @connection.client.selectedBuffer == this

  shouldRenderMessage: (message) ->
    message.msg? or Buffer.EVENT_TEXTS[message.type]?

  messageHandlers: {}

  initializedMessageHandlers: {}

window.Buffer = Buffer