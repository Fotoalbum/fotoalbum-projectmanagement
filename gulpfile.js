var elixir = require('laravel-elixir');

//Paths to libraries
var paths = {
    'bootstrap': 'node_modules/bootstrap-sass/assets/',
    'jquery': 'node_modules/jquery/'
}

/*
 |--------------------------------------------------------------------------
 | Elixir Asset Management
 |--------------------------------------------------------------------------
 |
 | Elixir provides a clean, fluent API for defining some basic Gulp tasks
 | for your Laravel application. By default, we are compiling the Less
 | file for our application, as well as publishing vendor resources.
 |
 */

elixir(function(mix) {
    /*
     * Sander
     *
     * 1) compile bootstrap sass
     * 2) copy bootstrap fonts from vendor to public
     * 3) mix jquery with bootstrap scripts to app.js
     */
    mix.sass('app.sass', 'public/css', {includePaths: [paths.bootstrap + 'stylesheets/']})
        .copy(paths.bootstrap + 'fonts/bootstrap/**', 'public/fonts')
        .scripts([
            paths.jquery + "dist/jquery.min.js",
            paths.bootstrap + "javascripts/bootstrap.js"
        ], 'public/js/app.js', './');
});
