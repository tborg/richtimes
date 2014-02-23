define (require) ->
  d3 = require 'd3'

  routeIsTarget = (transition, route) ->
    transition.targetName.replace('.index', '') is route.get('routeName')

  emptyParamsGetter = () -> []

  read = (path, paramsGetter=emptyParamsGetter) -> (opts={}) ->
    if @_cancelRead then @_cancelRead()
    read = new Ember.RSVP.Promise (resolve, reject) =>
      @set 'isLoading', true
      @_cancelRead = reject
      pathParams = paramsGetter.call @, opts
      if pathParams is null then return
      endpoint = path.fmt.apply path, pathParams
      $.getJSON(endpoint, opts).then(
        (content) =>
          @_cancelRead = null
          if not ((content.status_code or 200) in [200, 201]) then reject content
          resolve content.data
          @set 'isLoading', false
        (error) =>
          @set 'isLoading', false
          @_cancelRead = null
          reject error
      )

  numberPad2 = d3.format('02d')
  wcJsonFile = (params) -> '/static/json/%@-%@-wc.json'.fmt params.year, numberPad2 params.month

  {
    routeIsTarget
    read
    wcJsonFile
  }
