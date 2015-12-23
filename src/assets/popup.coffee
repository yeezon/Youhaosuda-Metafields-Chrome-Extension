# Vue.config.debug = true

popup = new Vue
  el: '#popup'
  data:
    msg: '无绑定店铺'
  created: ->
    self = this
    oBind = JSON.parse(localStorage.getItem('you_metas_ext-bind_data') || '{}')
    oShop = JSON.parse(localStorage.getItem('you_metas_ext-shop_data') || '{}')
    if oBind.bind
      if oShop.name
        self.msg = '已绑定：' + oShop.name
      else
        self.msg = '已绑定店铺'
