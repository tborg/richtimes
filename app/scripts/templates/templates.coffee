define (require) ->
  Ember = require 'ember'
  templates = [
    {name: 'issues', hbs: require 'text!./issues/issues.hbs'}
    {name: 'issues/issue', hbs: require 'text!./issues/issue.hbs'}
  ]
  for {name, hbs} in templates
    Ember.TEMPLATES[name] = Ember.Handlebars.compile hbs