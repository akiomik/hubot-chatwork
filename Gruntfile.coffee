module.exports = (grunt) ->
  grunt.initConfig
    mochacov:
      test:
        options:
          coverage: false
      coverage:
        options:
          reporter: 'html-cov'
          output: 'coverage.html'
      coveralls:
        options:
          coveralls:
            serviceName: 'travis-ci'
      options:
        files: 'test/*.coffee'
        compilers: ['coffee:coffee-script']

  grunt.loadNpmTasks 'grunt-mocha-cov'

  grunt.registerTask 'test', ['mochacov:test']
  grunt.registerTask 'coverage', ['mochacov:coverage']
  grunt.registerTask 'coveralls', ['mochacov:coveralls']

