require.config
	paths:
		app: './app'
		bootstrapAffix: '../vendor/sass-bootstrap/js/affix'
		bootstrapAlert: '../vendor/sass-bootstrap/js/alert'
		bootstrapButton: '../vendor/sass-bootstrap/js/button'
		bootstrapCarousel: '../vendor/sass-bootstrap/js/carousel'
		bootstrapCollapse: '../vendor/sass-bootstrap/js/collapse'
		bootstrapDropdown: '../vendor/sass-bootstrap/js/dropdown'
		bootstrapPopover: '../vendor/sass-bootstrap/js/popover'
		bootstrapScrollspy: '../vendor/sass-bootstrap/js/scrollspy'
		bootstrapTab: '../vendor/sass-bootstrap/js/tab'
		bootstrapTooltip: '../vendor/sass-bootstrap/js/tooltip'
		bootstrapTransition: '../vendor/sass-bootstrap/js/transition'
		d3: '../vendor/d3/d3'
		ember: '../vendor/ember/ember'
		emberData: '../vendor/ember-data/index'
		jquery: '../vendor/jquery/jquery'
		handlebars: '../vendor/handlebars/handlebars'
		lodash: '../vendor/lodash/dist/lodash'
		select2: '../vendor/select2/select2'
		spin: '../vendor/spin.js/spin'
		text: '../vendor/requirejs-text/text'

	shim:
		bootstrapAffix:
			deps: ['jquery']
		bootstrapAlert:
			deps: ['jquery']
		bootstrapButton:
			deps: ['jquery']
		bootstrapCarousel:
			deps: ['jquery']
		bootstrapCollapse:
			deps: ['jquery']
		bootstrapDropdown:
			deps: ['jquery']
		bootstrapPopover:
			deps: ['jquery']
		bootstrapScrollspy:
			deps: ['jquery']
		bootstrapTab:
			deps: ['jquery']
		bootstrapTooltip:
			deps: ['jquery']
		bootstrapTransition:
			deps: ['jquery']
		d3:
			exports: 'd3'
		ember:
			deps: ['jquery', 'handlebars']
			exports: 'Ember'
		emberData:
			deps: ['ember']
			exports: 'DS'
		lodash:
			exports: '_'
		select2:
			deps: ['jquery']

require ['./app'], -> # launches the application