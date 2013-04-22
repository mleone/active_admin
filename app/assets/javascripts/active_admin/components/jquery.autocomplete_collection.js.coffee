AutocompleteCollection = (element, options) ->
  @options = $.extend({}, $.fn.autocomplete_collection.defaults, options)
  @resource = @options.resource or @options.method
  @$element = $(element)
  @$element.wrap $(document.createElement('div')).addClass('autocomplete-collection-wrap')
  @$hidden = @$element.clone().attr('type','hidden').insertAfter(@$element)
  @$hidden.attr 'name', @$element.attr('name')
  @$element.removeAttr 'name'
  @matcher = @options.matcher or @matcher
  @sorter = @options.sorter or @sorter
  @highlighter = @options.highlighter or @highlighter
  @$menu = $(@options.menu).appendTo('body')
  @$collection = $(@options.collectionUi).insertAfter(@$element)
  @collection = @options.collection or JSON.parse(@$element.attr('data-collection')) or []
  @source = @options.source or @source
  @onselect = @options.onselect
  @onenter = @options.onenter
  @allowNew = @options.allowNew
  @strings = true
  @shown = false
  @build()
  @listen()

AutocompleteCollection.prototype =

  constructor: AutocompleteCollection

  # collection: ->
  #   JSON.parse(@$element.attr('data-collection')) or []

  collectionIds: ->
    $.map @collection, (o) -> o.id

  indexInCollection: (id) ->
    $.inArray id, @collectionIds()

  source: (autocomplete_collection, query) ->
    url = @$element.attr('data-json-url')
    xhr = $.getJSON(url+query)
    xhr.complete (data) =>
      resp = JSON.parse(data.responseText)
      resp = resp[@options.method] or resp
      autocomplete_collection.process(resp)

  select: (go) ->
    $active = @$menu.find('.active')
    if @allowNew and ($active.find("a").hasClass("add-new") or !@shown)
      @addNew()
    else
      val = JSON.parse($active.attr('data-value'))
      text = @getVal(val)
      @$element.val(text)
      @onselect(val, go) if typeof @onselect == "function"
      @add(val)
    @hide()

  addNew: ->
    text = @$element.val()
    val = @setVal(text)
    @add(val)
    @$element.val("")

  getVal: (val) ->
    if !@strings
      val[@options.property]
    else
      val

  setVal: (text) ->
    if !@strings
      val = {}
      val[@options.property] = text
      val
    else
      text

  show: ->
    pos = $.extend {}, @$element.offset(),
      height: @$element[0].offsetHeight
    @$menu.css
      top: pos.top + pos.height
      left: pos.left
    @$menu.show()
    @shown = true
    @

  hide: ->
    @$menu.hide()
    @shown = false
    @

  draw: (val) ->
    $li = $(document.createElement("li"))
      .addClass("autocomplete-collection-collection-item")
      .attr('data-autocomplete-collection-value', val[@options.property])
      .attr('data-autocomplete-collection-id', val.id)
      .html val[@options.property]
    $x = $(document.createElement("a"))
      .addClass("autocomplete-collection-remove-item")
      .html("&times;")
      .appendTo($li)
      .bind 'click', => @remove(val)
    @$collection.append $li
    @$element.val ""

  setValue: ->
    @$hidden.val JSON.stringify @collection
    # @$hidden.val $.map(@collection, (o) -> "'#{o.id.toString()}'" ).join(",")

  collectionAdd: (val) ->
    @collection.push(val)
    @setValue()

  collectionRemove: (i) ->
    @collection.splice i, 1
    @setValue()

  collectionReorder: (ids) ->
    that = @
    ordered_collection = []
    for id, i in ids
      do (id) ->
        index = that.indexInCollection(id)
        val = that.collection[index]
        val.position = i + 1
        ordered_collection.push val
    @collection = ordered_collection
    @setValue()

  add: (val) ->
    if i = @indexInCollection(val.id) == -1
      @draw(val)
      @collectionAdd(val)

  remove: (val) ->
    if (i = @indexInCollection(val.id)) > -1
      @collectionRemove(i)
      @$collection.find("[data-autocomplete-collection-id='#{val.id}']").remove()
    else if @allowNew
      text = @getVal(val)
      if ($item = @$collection.find("[data-autocomplete-collection-value='#{text}']")).length
        @collectionRemove(i)
        $item.remove()

  build: ->
    that = @
    $.each @collection, (i, val) ->
      that.draw(val)
    @setValue()
    if $.fn.sortable?
      @$collection.sortable
        stop: (e, ui) ->
          collectionIds = that.$collection.find("[data-autocomplete-collection-id]").map( ->
            parseInt $(@).attr("data-autocomplete-collection-id")
          ).get()
          that.collectionReorder(collectionIds)

  lookup: (event) ->
    that = @
    @query = @$element.val()
    if typeof @source == "function"
      value = @source(@, @query)
      if value
        @process(value)
      else
        @process(@source)

  process: (results) ->
    that = this
    if results.length and typeof results[0] != "string"
      @strings = false
    @query = @$element.val()
    if !@query
      if @shown then @hide() else this

    items = $.grep results, (item) ->
      if !that.strings
        item = item[that.options.property]
      if that.matcher(item)
        return item

    items = @sorter(items)
    if !items.length
      return if @shown then @hide() else @

    @render(items.slice(0, @options.items)).show()

  matcher: (item) ->
    ~item.toLowerCase().indexOf(@query.toLowerCase())

  sorter: (items) ->
    beginswith = []
    caseSensitive = []
    caseInsensitive = []

    while item = items.shift()
      if @strings
        sortby = item
      else
        sortby = item[@options.property]
      if !sortby.toLowerCase().indexOf(@query.toLowerCase())
        beginswith.push(item)
      else if ~sortby.indexOf(@query)
        caseSensitive.push(item)
      else
        caseInsensitive.push(item)

    beginswith.concat(caseSensitive, caseInsensitive)

  highlighter: (item) ->
    item.replace new RegExp('(' + @query + ')', 'ig'), ($1, match) ->
      return '<strong>' + match + '</strong>'

  render: (items) ->
    that = @
    items = $(items).map (i, item) ->
      i = $(that.options.item).attr('data-value', JSON.stringify(item))
      if !that.strings
        item = item[that.options.property]
        i.find('a').html(that.highlighter(item))
        return i[0]
    items.first().addClass('active')
    @$menu.html(items)
    if @allowNew
      $addNewLi = $(@options.item)
      $addNewLi.find("a").addClass('add-new icon-plus').html("Add new item")
      @$menu.append $addNewLi
    @

  next: (event) ->
    active = @$menu.find('.active').removeClass('active')
    next = active.next()
    if !next.length
      next = $(@$menu.find('li')[0])
    next.addClass('active')
    @

  prev: (event) ->
    active = @$menu.find('.active').removeClass('active')
    prev = active.prev()
    if !prev.length
      prev = @$menu.find('li').last()
    prev.addClass('active')
    @

  listen: ->
    @$element
      .on('blur',     $.proxy(@blur, @))
      .on('keypress', $.proxy(@keypress, @))
      .on('keyup',    $.proxy(@keyup, @))

    if $.browser.webkit or $.browser.msie
      @$element.on('keydown', $.proxy(@keypress, @))

    @$menu
      .on('click', $.proxy(@click, @))
      .on('mouseenter', 'li', $.proxy(@mouseenter, @))


  move: (e) ->
    if !@shown
      if e.keyCode == 13
        return false
      else
        return

    switch e.keyCode
      when 9, 13, 27
        e.preventDefault()
        break
      when 38
        e.preventDefault()
        @prev()
        break
      when 40
        e.preventDefault()
        @next()
        break

    e.stopPropagation()

  keydown: (e) ->
    @suppressKeyPressRepeat = ~$.inArray(e.keyCode, [40,38,9,13,27])
    @move(e)

  keypress: (e) ->
    return if @suppressKeyPressRepeat
    @move(e)

  keyup: (e) ->

    switch e.keyCode
      when 40, 38 # down / up arrow
        break
      when 9 # tab
        return if !@shown
        @select()
      when 13 # enter
        if !@shown
          @onenter(e) if typeof @onenter == "function"
          @select() if @allowNew
        else
          @select()
        break
      when 27 # escape
        return if !@shown
        @hide()
        break
      else
        @lookup()

    e.stopPropagation()
    e.preventDefault()

  focus: (e) ->
    @focused = true

  blur: (e) ->
    @focused = false
    that = @
    e.stopPropagation()
    e.preventDefault()
    setTimeout ->
      that.hide()
    , 150

  click: (e) ->
    e.stopPropagation()
    e.preventDefault()
    @select(true)
    @$element.focus()

  mouseenter: (e) ->
    @mousedover = true
    @$menu.find('.active').removeClass('active')
    $(e.currentTarget).addClass('active')

  mouseleave: (e) ->
    @mousedover = false
    @hide() if !@focused and @shown


$.fn.autocomplete_collection = (option) ->
  @each ->
    $this = $(@)
    data = $this.data('autocomplete-collection')
    options = typeof option == 'object' and option
    if !data
      $this.data('autocomplete-collection', (data = new AutocompleteCollection(@, options)))
    if typeof option == 'string'
      data[option]()

$.fn.autocomplete_collection.defaults =
  collectionUi: '<ul class="autocomplete-collection"></ul>'
  items: 8
  menu: '<ul class="autocomplete_collection dropdown-menu"></ul>'
  item: '<li><a href="#"></a></li>'
  onselect: null
  onenter: null
  allowNew: false
  property: 'name'

$.fn.autocomplete_collection.Constructor = AutocompleteCollection

$ ->

  $('[data-provide="autocomplete-collection"]').each ->
    $this = $(@)
    return if $this.data('autocomplete-collection')
    $this.autocomplete_collection($this.data())