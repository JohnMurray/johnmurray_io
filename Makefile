default: deploy

deploy:
	ps aux | grep jekyll | grep -v grep | awk '{print $2}' | xargs kill -9
	rm -rf _site
	bundle exec jekyll build
	g add _site
	g ci -m "rebuild of _site/ dir for release"
	g push github master
	g push heroku master
