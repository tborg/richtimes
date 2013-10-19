require.config({
    paths: {
        app: './app',
        bootstrapAffix: '../bower_components/sass-bootstrap/js/affix',
        bootstrapAlert: '../bower_components/sass-bootstrap/js/alert',
        bootstrapButton: '../bower_components/sass-bootstrap/js/button',
        bootstrapCarousel: '../bower_components/sass-bootstrap/js/carousel',
        bootstrapCollapse: '../bower_components/sass-bootstrap/js/collapse',
        bootstrapDropdown: '../bower_components/sass-bootstrap/js/dropdown',
        bootstrapPopover: '../bower_components/sass-bootstrap/js/popover',
        bootstrapScrollspy: '../bower_components/sass-bootstrap/js/scrollspy',
        bootstrapTab: '../bower_components/sass-bootstrap/js/tab',
        bootstrapTooltip: '../bower_components/sass-bootstrap/js/tooltip',
        bootstrapTransition: '../bower_components/sass-bootstrap/js/transition',
        d3: '../bower_components/d3/d3',
        ember: '../bower_components/ember/ember',
        emberData: '../bower_components/ember-data/index',
        jquery: '../bower_components/jquery/jquery',
        handlebars: '../bower_components/handlebars/handlebars',
        lodash: '../bower_components/lodash/dist/lodash',
        text: '../bower_components/requirejs-text/text'
    },
    shim: {
        bootstrapAffix: {
            deps: ['jquery']
        },
        bootstrapAlert: {
            deps: ['jquery']
        },
        bootstrapButton: {
            deps: ['jquery']
        },
        bootstrapCarousel: {
            deps: ['jquery']
        },
        bootstrapCollapse: {
            deps: ['jquery']
        },
        bootstrapDropdown: {
            deps: ['jquery']
        },
        bootstrapPopover: {
            deps: ['jquery']
        },
        bootstrapScrollspy: {
            deps: ['jquery']
        },
        bootstrapTab: {
            deps: ['jquery']
        },
        bootstrapTooltip: {
            deps: ['jquery']
        },
        bootstrapTransition: {
            deps: ['jquery']
        },
        d3: {
            exports: 'd3'
        },
        ember: {
            deps: ['jquery', 'handlebars'],
            exports: 'Ember'
        },
        emberData: {
            deps: ['ember'],
            exports: 'DS'
        },
        lodash: {
            exports: '_'
        }
    }
});

require(['./routes/router'], function () {
    'use strict';
});
