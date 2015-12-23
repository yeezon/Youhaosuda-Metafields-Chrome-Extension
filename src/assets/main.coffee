

# 数据格式

  # youMetasExt.api.msg
  # oMsg =
  #   type: ''
  #   key: ''
  #   cb_id: ''
  #   data: {}  # data/args/param

  # you_metas_ext-new_meta_delay
  # aNewMeta = [{
  #   ext_ver: EXT_VER
  #   date: dNowTime
  #   meta: oMeta
  # }]

  # you_metas_ext-up_meta_delay
  # aUpMetas = [{
  #   ext_ver: EXT_VER
  #   pro_id: sProID
  #   meta: oMeta
  # }]


do ->
  EXT_VER = '0.0.1'
  youMetasExt =
    canRun: true
    msgPort: null
    sendMsgCBs: {}
    fn:
      getX: ->
        (Date.parse(new Date()) + Math.random()).toString()
      parseHTML: (html) ->
        eDiv = document.createElement('div')
        eDiv.innerHTML = html
        return eDiv.childNodes[0]
      metaFormat: (oMeta) ->
        JSON.parse(JSON.stringify(oMeta).replace(/\:[\s]*\"true\"/g, ':true').replace(/\:[\s]*\"false\"/g, ':false'))
    api:
      msg: (data, cb) ->
        yme = youMetasExt
        cb_id = do yme.fn.getX
        while yme.sendMsgCBs[cb_id]
          cb_id = do yme.fn.getX
        yme.sendMsgCBs[cb_id] = cb
        data['cb_id'] = cb_id
        yme.msgPort.postMessage data
      isBind: (domain, cb) ->
        self = this
        self.msg
          type: 'api'
          key: 'isBind'
          data: [domain]
        , cb
      setLocal: (key, data) ->
        localStorage.setItem(key, JSON.stringify data)
      getLocal: (key) ->
        JSON.parse(localStorage.getItem(key) || null)
      getPro: (id, cb) ->
        self = this
        self.msg
          type: 'api'
          key: 'products.get'
          data: [id]
        , cb
      getProMetas: (sProID, cb) ->
        self = this
        self.msg
          type: 'api'
          key: 'metas.find'
          data: [{
            name: 'metas_ext'
            owner_id: sProID
          }]
        , cb
      addProMeta: (sProID, oMeta, cb) ->
        self  = this
        _data =
          meta: 
            name: 'metas_ext',
            owner_id: sProID,
            owner_resource: 'product',
            fields: oMeta
            description: '商品数据拓展'
        self.msg
          type: 'api'
          key: 'metas.add'
          data: [_data]
        , cb

      upProMeta: (sProID, oUpMeta, cb) ->
        self = this
        self.getProMetas sProID, (err, data) ->
          # 可优化，复用已获取的 Meta 信息，去掉 getProMetas
          if err
            cb err
          else
            self.upMeta data.metas[0], oUpMeta, (err, data) ->
              if err
                cb err
              else
                cb null, data

      upMeta: (oMeta, oUpMeta, cb) ->
        self = this
        _data =
          meta:
            name: oMeta.name
            owner_id: oMeta.owner_id
            owner_resource: oMeta.owner_resource
            fields: oUpMeta
        self.msg
          type: 'api'
          key: 'metas.up'
          data: [oMeta.id, _data]
        , cb
    init: ->
      self = this

      self.msgPort = chrome.runtime.connect name: 'msg'

      self.msgPort.onMessage.addListener (oMsg) ->
        cb = self.sendMsgCBs[oMsg.cb_id]
        delete self.sendMsgCBs[oMsg.cb_id]
        cb.apply(true, oMsg.data) if cb

  # Main
  window.addEventListener 'hashchange', (evt) ->
    do start

  fnCheck = (sel) ->
    elItem = document.querySelector sel
    if elItem
      dataInit (err, sProID, _oMeta)->
        setUI err, sProID, _oMeta
    else
      setTimeout ->
        fnCheck sel
      , 300

  # 源数据备份
  jsonMetaBak = null

  # 数据初始化
  dataInit = (cb) ->
    fn = youMetasExt.fn
    api = youMetasExt.api
    sProID = (location.hash.replace /^\#\/productedit\?id\=/, '').replace /&.*$/, ''

    _oDefaultMeta =
      is_buy: true
      is_try: false
      is_video: false
      video_src: ''
      attr_desc: ''
      desc: ''

    jsonMetaBak = JSON.stringify _oDefaultMeta

    _fnGetProMetas = ->
      unless /new/.test sProID
        api.getProMetas sProID, (err, data) ->
          if err
            cb err
          else
            if data.metas
              if data.metas.length == 0
                api.addProMeta sProID, _oDefaultMeta, (err, data) ->
                  if err
                    console.log '数据初始化添加默认数据错误'
                    cb err
                  else
                    cb null, sProID, _oDefaultMeta
                    # 有空换成注入 返回的数据，cb & jsonMetaBak
              else
                _oMeta      = fn.metaFormat data.metas[0].fields
                jsonMetaBak = JSON.stringify _oMeta
                cb null, sProID, _oMeta
            else
              cb '获取 Meta 数据错误'
      else
        cb null, sProID, _oDefaultMeta

    do _fnGetProMetas

    # 出错延迟更新机制（暂时去掉，因为有还原数据）
    # aUpMetas = api.getLocal 'you_metas_ext-up_meta_delay'
    # if aUpMetas && aUpMetas.length != 0
    #   api.upProMeta aUpMetas[0].pro_id, aUpMetas[0].meta, (err, data) ->
    #     if !err
    #       aUpMetas.splice 0, 1
    #       api.setLocal 'you_metas_ext-up_meta_delay', aUpMetas
    #     do _fnGetProMetas
    # else
    #   do _fnGetProMetas

   
  
  setUI = (err, sProID, _oMeta) ->
    fn = youMetasExt.fn
    api = youMetasExt.api

    mainTpl = '' +
      '<div v-if="!err && !is_new_page" class="fw-main-item-content fw-main-item-content-full you_metas_ext-row">' +
      '  <div class="you_metas_ext-col">' +
      '    <div class="setting-create-way you_metas_ext-item">' +
      '        <h2>商品类型</h2>' +
      '        <div class="create-way-block">' +
      '            <label class="labelmargin"><label class="check"><input type="checkbox" v-model="meta.is_buy" @change="change" class="ng-pristine ng-untouched ng-valid check-checkbox"><span class="check-fake"></span></label>购买</label>' +
      '            <thislabel class="labelmargin"><label class="check"><input type="checkbox" v-model="meta.is_try" @change="change" class="ng-valid check-checkbox ng-dirty ng-valid-parse ng-touched"><span class="check-fake"></span></label>体验</label>' +
      '        </div>' +
      '    </div>' +
      '    <div class="setting-create-way you_metas_ext-item">' +
      '      <h2>视频</h2>' +
      '      <div class="create-way-block">' +
      '        <label class="labelmargin"><label class="check"><input type="checkbox" v-model="meta.is_video" @change="change" class="ng-pristine ng-untouched ng-valid check-checkbox"><span class="check-fake"></span></label>显示</label>' +
      '      </div>' +
      '      <div class="create-way-block">' +
      '        <input type="text" class="input input-search ng-pristine ng-valid ng-touched" placeholder="视频地址" v-model="meta.video_src" @change="change">' +
      '      </div>' +
      '    </div>' +
      '    <div class="setting-create-way you_metas_ext-item">' +
      '        <h2>背景图<span class="theme-seo-tip ng-binding">对应最后一张橱窗图片，此图将不显示</span></h2>' +
      '    </div>' +
      '  </div>' +
      '  <div class="you_metas_ext-col">' +
      '    <div class="setting-create-way you_metas_ext-item">' +
      '        <h2>属性描述</h2>' +
      '        <div class="create-way-block">' +
      '          <input class="input input-long ng-pristine ng-valid ng-valid-maxlength ng-touched" type="text" v-model="meta.attr_desc" @change="change" placeholder="请输入属性描述" maxlength="70">' +
      '        </div>' +
      '    </div>' +
      '    <div class="setting-create-way you_metas_ext-item">' +
      '        <h2>描述</h2>' +
      '        <div class="create-way-block">' +
      '          <textarea rows="3" class="input input-long ng-pristine ng-untouched ng-valid ng-valid-maxlength" v-model="meta.desc" @change="change" placeholder="请输入描述" style="max-height: 72px;" maxlength="128"></textarea>' +
      '        </div>' +
      '    </div>' +
      '  </div>' +
      '</div>' +
      '' +
      '<div v-if="err && !is_new_page" class="fw-main-item-content fw-main-item-content-full you_metas_ext-info you_metas_ext-err">' +
      '  <div class="setting-create-way you_metas_ext-item">' +
      '    <span><span>请刷新页面</span><br><span>{{err}}</span></span>' +
      '  </div>' +
      '</div>' +
      '' +
      '<div v-if="!err && is_new_page" class="fw-main-item-content fw-main-item-content-full you_metas_ext-info">' +
      '  <div class="setting-create-way you_metas_ext-item">' +
      '    <span><span>新增商品后方可设置自定义属性</span></span>' +
      '  </div>' +
      '</div>'

    _data =
      is_change: false
      is_new_page: /new/.test sProID
      err: err
      meta: _oMeta

    # 插入 DOM
    elNode = document.querySelectorAll('.fw-main-item')[2]
    elNode.parentNode.insertBefore(fn.parseHTML('<div id="pro_metas" class="fw-main-item you_metas_ext"></div>'), elNode.nextSibling)

    proMetas = new Vue
      el: '#pro_metas'
      replace: false
      template: mainTpl
      data: _data
      methods:
        change: ->
          self = this
          self.is_change = true
      ready: ->
        self = this
        for el in document.querySelectorAll('.btn-primary[text="保存"]')
          el.addEventListener 'click', (evt) ->
            api.upProMeta sProID, self.meta, (err, data) ->
              if err
                console.log err

                # 还原数据
                self.meta = JSON.parse jsonMetaBak

                # 出错延迟更新机制（暂时去掉，因为有还原数据）
                # aUpMetas = api.getLocal 'you_metas_ext-up_meta_delay'
                # if !aUpMetas
                #   aUpMetas = []
                # aUpMetas.push
                #   ext_ver: EXT_VER
                #   pro_id: sProID
                #   meta: self.meta
                # api.setLocal 'you_metas_ext-up_meta_delay', aUpMetas

              else
                self.meta   = fn.metaFormat data.meta.fields
                jsonMetaBak = JSON.stringify self.meta

  do start = ->
    if location.hash.indexOf('\#\/productedit\?id\=') > -1
      if youMetasExt.canRun
        youMetasExt.canRun = false
        do youMetasExt.init
      youMetasExt.api.isBind location.hostname, (isBind) ->
        if isBind
          fnCheck '.fw-main-item'



  # main.js
  # Post Msg
  # postMsg = (oMsg, cb) ->
  #   chrome.runtime.sendMessage null, oMsg, null, cb

  # index.js
  # Post Msg
  # chrome.runtime.onMessage.addListener (oMsg, sender, cb) ->
  #   if msg.type == 'get_pro'
  #     api.products.get msg.id, (err, data) ->
  #       result =
  #         err: null
  #         data: null
  #       if err
  #         result.err = err
  #       else
  #         result.data = data
  #       console.log 222
  #       cb JSON.stringify(result)