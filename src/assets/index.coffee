Vue.config.debug = true

API_URI   = 'https://api.youhaosuda.com/v1'
TOKEN_URI = 'https://apps.youhaosuda.com/oauth2/token'

# 全局对象
oBind =
  bind         : false
  app_key      : ''
  shared_secret: ''
  token        : null
oShop =
  name: ''
  domain: ''

# Send Msg
chrome.runtime.onConnect.addListener (msgPort) ->
  sendMsg = (data) ->
    msgPort.postMessage data
  msgPort.onMessage.addListener (oMsg) ->
    if oMsg.type == 'api'
      aKeys = oMsg.key.split '.'
      _api  = api
      for v in aKeys
        _api = _api[v]
      if Array.isArray(oMsg.data)
        oMsg.data.push (err, data)->
          sendMsg
            type : oMsg.type
            key  : oMsg.key
            cb_id: oMsg.cb_id
            data : [err, data]
        _api.apply null, oMsg.data

api =
  checkToken: ->
    _oBind = JSON.parse(localStorage.getItem('you_metas_ext-bind_data') || '{}')
    _oBind.token || ''

  isBind: (domain, cb) ->
    isBind = !!(JSON.parse(localStorage.getItem('you_metas_ext-bind_data') || '{}')).bind
    isShop = (domain == (JSON.parse(localStorage.getItem('you_metas_ext-shop_data') || '{}')).domain)
    cb isBind && isShop

  getToken: (sAppKey, sSharedSecret, cb) ->
    encoded = Base64.encode(sAppKey + ':' + sSharedSecret)
    xhr = new XMLHttpRequest()
    xhr.open 'POST', TOKEN_URI, true
    xhr.setRequestHeader 'Authorization', 'Basic ' + encoded
    xhr.setRequestHeader 'Content-type', 'application/x-www-form-urlencoded'
    xhr.onreadystatechange = ->
      if xhr.readyState == 4
        if xhr.status == 200
          result = JSON.parse xhr.responseText
          cb null, result
        else
          result = JSON.parse xhr.responseText
          console.log result.error
          cb '绑定失败'
    xhr.send 'grant_type=client_credentials'

  get: (api, data, cb) ->
    self  = this
    uri   = API_URI + api
    token = oBind.token

    if !token
      token = oBind.token = self.checkToken()

    qs = ''
    for k, v of data
      qs += '&' + k + '=' + v
    qs = qs.replace /^&/, ''
    if qs
      uri = uri + '?' + qs

    xhr = new XMLHttpRequest()
    xhr.open 'GET', uri, true
    xhr.setRequestHeader 'X-API-ACCESS-TOKEN', token
    xhr.onreadystatechange = ->
      if xhr.readyState == 4
        if xhr.status == 200
          result = JSON.parse xhr.responseText
          cb null, result
        else
          console.log xhr.responseText
          cb '服务器请求错误'
    do xhr.send

  post: (api, data, cb) ->
    self  = this
    uri   = API_URI + api
    token = oBind.token

    if !token
      token = oBind.token = self.checkToken()

    xhr = new XMLHttpRequest()
    xhr.open 'POST', uri, true
    xhr.setRequestHeader 'X-API-ACCESS-TOKEN', token
    xhr.setRequestHeader 'Content-Type', 'application/json'
    xhr.onreadystatechange = ->
      if xhr.readyState == 4
        if xhr.status == 200
          result = JSON.parse xhr.responseText
          cb null, result
        else
          console.log xhr.responseText
          cb '服务器请求错误'
    data = {} if !data
    xhr.send(JSON.stringify data)

  put: (api, data, cb) ->
    self  = this
    uri   = API_URI + api
    token = oBind.token

    if !token
      token = oBind.token = self.checkToken()

    xhr = new XMLHttpRequest()
    xhr.open 'PUT', uri, true
    xhr.setRequestHeader 'X-API-ACCESS-TOKEN', token
    xhr.setRequestHeader 'Content-Type', 'application/json'
    xhr.onreadystatechange = ->
      if xhr.readyState == 4
        if xhr.status == 200
          result = JSON.parse xhr.responseText
          cb null, result
        else
          console.log xhr.responseText
          cb '服务器请求错误'
    data = {} if !data
    xhr.send(JSON.stringify data)

  shop:
    get: (cb) ->
      api = api
      api.get '/shop', null, cb

  products:
    get: (id, cb) ->
      api = api
      api.get '/products/' + id, null, cb
  metas:
    find: (data, cb) ->
      api = api
      api.get '/metas', data, cb
    get: (id, cb) ->
      api = api
      api.get '/metas/' + id, null, cb
    add: (data, cb) ->
      api = api
      api.post '/metas', data, cb
    up: (id, data, cb) ->
      api = api
      api.put '/metas/' + id, data, cb

index = new Vue
  el: '#index'
  data:
    msg: '无绑定店铺'
    oBind: oBind
    oShop: oShop
  methods:
    fnBind: ->
      self = this
      api.getToken self.oBind.app_key, self.oBind.shared_secret, (err, data) ->
        if err
          self.oBind.bind = false
          self.msg = err
        else
          self.msg         = '已绑定店铺'
          self.oBind.bind  = true
          self.oBind.token = data.token
          localStorage.setItem('you_metas_ext-bind_data', JSON.stringify self.oBind)
          api.shop.get (err, data) ->
            if err
              console.log err
            else
              self.oShop.name   = data.shop.name
              self.oShop.domain = data.shop.domain
              localStorage.setItem('you_metas_ext-shop_data', JSON.stringify self.oShop)
    fnUnbind: ->
      self = this
      self.msg = '解绑成功'
      do self.clearBind
    clearBind: ->
      self = this
      self.oBind =
        bind         : false
        app_key      : ''
        shared_secret: ''
        token        : null
      self.oShop =
        name: ''
        domain: ''
      localStorage.setItem 'you_metas_ext-bind_data', ''
      localStorage.setItem 'you_metas_ext-shop_data', ''
  created: ->
    self = this
    _oBind = JSON.parse(localStorage.getItem('you_metas_ext-bind_data') || '{}')
    if _oBind.bind
      self.oBind.bind       = _oBind.bind
      self.oBind.app_key    = _oBind.app_key
      self.oBind.app_secret = _oBind.app_secret
      self.oBind.token      = _oBind.token
      api.shop.get (err, data) ->
        if err
          console.log err
        else
          self.oShop.name   = data.shop.name
          self.oShop.domain = data.shop.domain
          localStorage.setItem('you_metas_ext-shop_data', JSON.stringify self.oShop)

        if self.oShop.name
          self.msg = '已绑定：' + self.oShop.name
        else
          self.msg = '已绑定店铺'








