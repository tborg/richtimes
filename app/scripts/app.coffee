define (require) ->
  Ember = require 'ember'
  require 'select2'
  require 'bootstrapCollapse'


  App = Ember.Application.create
    LOG_TRANSITIONS: true


  routeIsTarget = (transition, route) ->
    transition.targetName.replace('.index', '') is route.get('routeName')


  templates = [
    {name: 'index', hbs: require 'text!./templates/index.hbs'}
    {name: 'content', hbs: require 'text!./templates/content.hbs'}
    {name: 'content/articles', hbs: require 'text!./templates/content/articles.hbs'}
  ]

  for {name, hbs} in templates
    Ember.TEMPLATES[name] = Ember.Handlebars.compile hbs

  App.ApplicationView = Ember.View.extend
    didInsertElement: () ->
      @_super()
      @$('footer a').click(() -> $('body').animate(scrollTop: '0'); false)

  App.ApplicationRoute = Ember.Route.extend
    events:
      error: (error, transition) ->
        @transitionTo 'content'


  App.ContentController = Ember.ObjectController.extend
    category_id: null
    content_type_id: null
    issue_id: null,

    categoryIds: (() ->
      Ember.keys(@get('content'))
    ).property('content')

    contentTypeIds: (() ->
      category_id = @get 'category_id'
      if not category_id then return []
      Ember.keys((@get 'content.%@'.fmt category_id) or {})
    ).property('content', 'category_id')

    issueIds: (() ->
      category_id = @get 'category_id'
      content_type_id = @get 'content_type_id'
      if not category_id or not content_type_id then return []
      Ember.keys(@get('content.%@.%@'.fmt category_id, content_type_id) or {})
    ).property('contentTypeIds', 'content_type_id')

    contentChanged: (() ->
      {category_id, content_type_id, issue_id} = @getProperties ['category_id', 'content_type_id', 'issue_id']
      category = @get category_id
      if not @get '%@.%@'.fmt category_id, content_type_id
        @set 'content_type_id', content_type_id = @get 'contentTypeIds.0'
      if not @get '%@.%@.%@'.fmt category_id, content_type_id, issue_id
        @set 'issue_id', issue_id = @get 'issueIds.0'
      article_ids = @get('%@.%@.%@'.fmt category_id, content_type_id, issue_id) or []
      @transitionToRoute 'content.articles',
        {category_id, content_type_id, issue_id, article_ids}
    ).observes('category_id', 'content_type_id', 'issue_id')

    nextCategory: (() ->
      ids = @get('categoryIds')
      index = ids.indexOf(@get 'category_id') + 1
      ids[index]
    ).property('category_id', 'categoryIds')

    prevCategory: (() ->
      ids = @get('categoryIds')
      index = ids.indexOf(@get 'category_id') - 1
      ids[index]
    ).property('category_id', 'categoryIds')
    
    nextContentType: (() ->
      ids = @get('contentTypeIds')
      index = ids.indexOf(@get 'content_type_id') + 1
      ids[index]
    ).property('content_type_id', 'contentTypeIds')

    prevContentType: (() ->
      ids = @get('contentTypeIds')
      index = ids.indexOf(@get 'content_type_id') - 1
      ids[index]
    ).property('content_type_id', 'contentTypeIds')

    nextIssue: (() ->
      ids = @get('issueIds')
      index = ids.indexOf(@get 'issue_id') + 1
      ids[index]
    ).property('issue_id', 'issueIds')

    prevIssue: (() ->
      ids = @get('issueIds')
      index = ids.indexOf(@get 'issue_id') - 1
      ids[index]
    ).property('issue_id', 'issueIds')

    actions:
      next: (type) ->
        switch type
          when 'issue'
            if id = @get 'nextIssue'
              @set 'issue_id', id
          when 'category'
            if id = @get 'nextCategory'
              @set 'category_id', id
          when 'contentType'
            if id = @get 'nextContentType'
              @set 'content_type_id', id

      prev: (type) ->
        switch type
          when 'issue'
            if id = @get 'prevIssue'
              @set 'issue_id', id
          when 'category'
            if id = @get 'prevCategory'
              @set 'category_id', id
          when 'contentType'
            if id = @get 'prevContentType'
              @set 'content_type_id', id


  App.ContentRoute = Ember.Route.extend
    model: (params) ->
      new Ember.RSVP.Promise (resolve, reject) =>
        if content = @modelFor('content') then return resolve content
        $.getJSON('/content').then(resolve, reject)

    afterModel: (model, transition) ->
      if routeIsTarget(transition, @)
        {category_id, content_type_id, issue_id} = @controllerFor('content')
          .getProperties(['category_id', 'content_type_id', 'issue_id'])
        if not category_id or not content_type_id or not issue_id
          category_id = Ember.keys(model)[0]
          @controllerFor('content')
            .set('content', model)
            .set('category_id', category_id)
        else
          @controllerFor('content').notifyPropertyChange 'category_id'


  App.ContentView = Ember.View.extend
    didInsertElement: () ->
      @_super()
      query = (prop) => ({term, callback}) =>
        callback results: @get('controller.%@'.fmt prop)
          .filter((d) -> d.toLowerCase().match term)
          .map((d) -> text: d, id: d)

      update = (prop) => (e) =>
        @set('controller.%@'.fmt(prop), e.val)

      initSelection = (prop) => (el, callback) =>
        id = @get 'controller.%@'.fmt prop
        callback id: id, text: id

      @categories = @$('.categories input[type="hidden"]').select2(
        query: query 'categoryIds'
        initSelection: initSelection 'category_id'
      )
        .on('change', update 'category_id')
      @contentTypes = @$('.content-types input[type="hidden"]').select2(
        query: query 'contentTypeIds'
        initSelection: initSelection 'content_type_id'
      )
        .on('change', update 'content_type_id')
      @issues = @$('.issues input[type="hidden"]').select2(
        query: query 'issueIds'
        initSelection: initSelection 'issue_id'
      )
        .on('change', update 'issue_id')

    category_idChanged: (() ->
      if not @categories then return
      val = @get 'controller.category_id'
      selectorVal = @categories.select2 'val'
      if selectorVal isnt val then @categories
        .select2('val', val)
    ).observes('controller.category_id', 'controller.categoryIds')

    content_type_idChanged: (() ->
      if not @contentTypes then return
      val = @get 'controller.content_type_id'
      selectorVal = @contentTypes.select2 'val'
      if selectorVal isnt val then @contentTypes
        .select2('val', val)
    ).observes('controller.content_type_id', 'controller.contentTypeIds')

    issue_idChanged: (() ->
      if not @issues then return
      val = @get 'controller.issue_id'
      selectorVal = @issues.select2 'val'
      if selectorVal isnt val then @issues
        .select2('val', val)
    ).observes('controller.issue_id', 'controller.issueIds')

    willDestroyElement: () ->
      @categories.select2('destroy')
      @contentTypes.select2('destroy')
      @issues.select2('destroy')
      @_super()

  App.ContentArticlesRoute = Ember.Route.extend
    model: (params, transition) ->
      if not params.article_ids
        {category_id, content_type_id, issue_id} = params
        params.article_ids = $.makeArray @modelFor('content')[category_id][content_type_id][issue_id]
      params

    setupController: (controller, model) ->
      @controller.set 'content', model
      @controllerFor('content').setProperties model
      $.getJSON('/content/articles',
        ids: model.article_ids.join ','
      ).then(
        (articles) -> controller.set('articles', articles.articles)
      )

  App.Router.map () ->
    @resource 'content', ->
      @route 'articles', path: '/:category_id/:content_type_id/:issue_id'
    @resource 'people'
    @resource 'places'
    @resource 'orgs'
    @resource 'things'
    @route 'missing', {path: '/*path'}

