define (require) ->
  Ember = require 'ember'
  templates = [
    {name: 'sections', hbs: require 'text!./sections/sections.hbs'}
    {name: 'subsections', hbs: require 'text!./sections/subsections.hbs'}
    {name: 'issues', hbs: require 'text!./sections/issues.hbs'}
    {name: 'issues/issue', hbs: require 'text!./sections/issue.hbs'}
  ]
  for {name, hbs} in templates
    Ember.TEMPLATES[name] = Ember.Handlebars.compile hbs