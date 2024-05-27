default: deploy

.PHONY: deploy
deploy: build_container
	rm -rf _site
	docker run --rm -v $(shell pwd):/source -w /source johnmurray_io:latest \
        bundle exec jekyll build
	cp blog-files/ads.txt _site/
	git add _site
	git ci -m "rebuild of _site/ dir for release"
	git push origin master
	git push heroku master

.PHONY: serve
serve: build_container
	docker run --rm -v $(shell pwd):/source --expose 4000 -p 4000:4000 -w /source johnmurray_io:latest \
		bundle exec jekyll serve --drafts -H "0.0.0.0" -P 4000

.PHONY: clean
clean:
	@docker rmi $(docker images -a -q -f dangling=true) 2>/dev/null || echo "No dangling images to remove"
	@docker rm $(docker ps --filter=status=exited --filter=status=created -q) 2>/dev/null || echo "No exited or created containers to remove"
	@docker system prune -f

.PHONY: build_container
build_container:
	docker build -t johnmurray_io:latest .

.PHONY: run_container
run_container:
	# run conainer and mount /source in the image to our current directory
	docker run -ti --rm -v $(shell pwd):/source -p 4000:4000 -w /source johnmurray_io:latest /bin/bash
