define (require) ->
  Ember = require 'ember'
  templates = [
    {name: 'home', hbs: require 'text!./templates/home.hbs'}
    {name: 'content', hbs: require 'text!./templates/content.hbs'}
    {name: 'content/type', hbs: require 'text!./templates/content/type.hbs'}
    {name: 'content/type/section', hbs: require 'text!./templates/content/type/section.hbs'}
  ]
  for {name, hbs} in templates
    Ember.TEMPLATES[name] = Ember.Handlebars.compile hbs