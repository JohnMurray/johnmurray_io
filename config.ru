require 'rack'
require 'rack/contrib/try_static'

use Rack::TryStatic, 
      :root => "_site",  # static files root dir
      :urls => %w[/],     # match all requests 
      :try => ['.html', 'index.html', '/index.html'] # try these postfixes sequentially

# otherwise 404 NotFound
notFoundPage = File.open('_site/index.html').read
run lambda { |_| [200, {'Content-Type' => 'text/html'}, [notFoundPage]]}
