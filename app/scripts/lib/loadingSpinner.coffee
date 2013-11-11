define (require) ->
  Spinner = require 'spin'
  Ember = require 'ember'

  Ember.Component.extend
    classNames: ['loading-spinner']
    classNameBindings: ['isLoading']

    _options:
      lines: 7  # The number of lines to draw
      length: 20  # The length of each line
      width: 22  # The line thickness
      radius: 30  # The radius of the inner circle
      corners: 1  # Corner roundness (0..1)
      rotate: 0  # The rotation offset: counterclockwise  direction: 1  # 1: clockwise
      color: '#000' # #rgb or #rrggbb or array of colors
      speed: 1  # Rounds per second
      trail: 60  # Afterglow percentage
      shadow: false  # Whether to render a shadow
      hwaccel: false  # Whether to use hardware acceleration
      className: 'spinner' # The CSS class to assign to the spinner
      zIndex: 2e9  # The z-index (defaults to 2000000000)
      top: 'auto' # Top position relative to parent in px
      left: 'auto' # Left position relative to parent in px

    isLoading: false

    didInsertElement: () ->
      @_super()
      @node = @$('.spinner')[0]
      options = Ember.Object.create(@get('_options'), @get('options'))
      @spinner = new Spinner(options)
      if @get 'isLoading' then @spinner.spin(@node)

    isLoadingChanged: (() ->
      isLoading = @get 'isLoading'
      if isLoading then @spinner.spin(@node) else @spinner.stop()
    ).observes('isLoading')