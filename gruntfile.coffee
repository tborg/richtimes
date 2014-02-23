module.exports = (grunt) ->
  path = require 'path'

  # Show elapsed time at the end.
  require('time-grunt') grunt

  # load all tasks
  require('load-grunt-tasks') grunt


  pathUtility = (root) -> (p) -> path.join root, p

  build = pathUtility 'build'
  dist = pathUtility 'dist'
  dev = pathUtility 'app'
  server = pathUtility 'server'
  htdocs = pathUtility 'htdocs'
  bower = pathUtility 'bower_components'
  bootstrap = pathUtility 'sass-bootstrap'

  paths =
    vendor:
      dest: htdocs 'vendor'
      cwd: bower '/'
      src: [
        bootstrap 'js/affix.js'
        bootstrap 'js/alert.js'
        bootstrap 'js/button.js'
        bootstrap 'js/carousel.js'
        bootstrap 'js/collapse.js'
        bootstrap 'js/dropdown.js'
        bootstrap 'js/popover.js'
        bootstrap 'js/scrollspy.js'
        bootstrap 'js/tab.js'
        bootstrap 'js/tooltip.js'
        bootstrap 'js/transition.js'
        bootstrap 'fonts/*.*'
        'd3/d3.js'
        'ember/ember.js'
        'ember-data/index.js'
        'jquery/jquery.js'
        'handlebars/handlebars.js'
        'lodash/dist/lodash.js'
        'modernizr/modernizr.js'
        'select2/select2.js'
        'select2/select2.css'
        'select2/select2.png'
        'select2/select2-spinner.gif'
        'spin.js/spin.js'
        'requirejs/require.js'
        'requirejs-text/text.js'
      ]
    xml:
      dest: htdocs 'xml'
      cwd: bower 'richtimes-xml'
      src: '*.xml'
    scripts:
      dest: htdocs 'js'
      cwd: dev 'scripts'
      src: '**/*.coffee'
    styles:
      dest: htdocs 'css'
      cwd: dev 'styles'
      src: '/**/*.scss'
    json:
      dest: htdocs 'json'
      cwd: dev 'json'
      src: '*.json'
    images:
      dest: htdocs 'images'
      cwd: dev 'images'
      src: '*.*'
    templates:
      dest: htdocs 'js'
      cwd: dev 'scripts'
      src: '**/*.hbs'
    server:
      dest: '/'
      cwd: server '/'
      src: ['**/*.py', 'supervisord.conf']
    misc:
      dest: htdocs '/'
      cwd: dev '/'
      src: [
        '404.html'
        'favicon.ico'
        'index.html'
        'robots.txt'
        '.htaccess'
      ]
    css:
      dest: htdocs 'css'
        

  grunt.initConfig
    paths: paths

    # COFFEE SCRIPTS

    coffee:
      build:
        files: [
          expand: true
          dest: build paths.scripts.dest
          src: paths.scripts.src
          cwd: paths.scripts.cwd
          ext: '.js'
        ]
      dist:
        files: [
          expand: true
          dest: dist paths.scripts.dest
          src: paths.scripts.src
          cwd: paths.scripts.cwd
          ext: '.js'
        ]

    # SASS STYLES

    compass:
      build:
        options:
          sassDir: dev 'styles'
          cssDir: build paths.styles.dest
          importPath: [bower bootstrap 'lib']
      dist:
        options:
          sassDir: dev 'styles'
          cssDir: dist paths.styles.dest
          importPath: [bower bootstrap 'lib']

    # COPY

    copy:
      build:
        files: [
          'misc'
          'vendor'
          'json'
          'images'
          'templates'
        ].map (d) ->
          expand: true
          dot: true
          cwd: paths[d].cwd
          dest: build paths[d].dest
          src: paths[d].src
      build_xml:
        files: [
          {
            expand: true
            dot: true
            cwd: paths.xml.cwd
            dest: build paths.xml.dest
            src: paths.xml.src
          }
        ]
      dist_xml:
        files: [
          {
            expand: true
            dot: true
            cwd: paths.xml.cwd
            dest: dist paths.xml.dest
            src: paths.xml.src
          }
        ]
      dist:
        files: [
          'vendor'
          'json'
          'images'
          'templates'
          'misc'
          'server'
        ].map (d) ->
          expand: true
          dot: true
          cwd: paths[d].cwd
          dest: dist paths[d].dest
          src: paths[d].src


    # CLEAN

    clean:
      build:
        files: Object.keys(paths).map (k) ->
          {dest, src, cwd} = paths[k]
          dot: true
          force: true
          src: build dest
      dist:
        files: Object.keys(paths).map (k) ->
          {dest, src, cwd} = paths[k]
          dot: true 
          force: true
          src: dist dest


    # DEV ENV

    watch:
      coffee:
        files: ['app/scripts/**/*.coffee']
        tasks: ['coffee:build']
      compass:
        files: [path.join paths.styles.cwd, paths.styles.src]
        tasks: ['compass:build']
      # livereload:
      #   options:
      #     livereload: '<%= connect.options.livereload %>'
      #   files: [build '**/*']
      htdocs:
        files: [
          'misc'
          'templates'
          'json'
          'images'
        ]
          .map((d) -> [paths[d].cwd, paths[d].src])
          .reduce(
            (files, [cwd, src]) ->
              if not Array.isArray src then src = [src]
              dir = pathUtility cwd
              files.concat src.map dir
            []
          )

        tasks: ['copy:build']
    connect:
      options:
        port: 9000
        livereload: 36729
        hostname: 'localhost'
      livereload:
        options:
          open: true
          base: [build 'htdocs']


    # TASK GROUPS

    concurrent:
      build: [
        'coffee:build'
        'compass:build'
        'copy:build'
      ]
      dist: [
        'coffee:dist'
        'compass:dist'
        'copy:dist'
      ]

  grunt.registerTask 'flask', 'Run the flask server', ->
    {spawn} = require 'child_process'
    grunt.log.writeln 'Starting Flask Dev Server'
    spawn 'env/bin/python', ['server/main.py'], stdio: 'inherit'

  grunt.registerTask 'server', [
    'clean:build'
    'copy:build_xml'
    'concurrent:build'
    'flask'
    'watch'
  ]

  grunt.registerTask 'default', [
    'clean:dist'
    'copy:dist_xml'
    'concurrent:dist'
  ]