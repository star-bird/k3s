all: clean build
clean:
	@if [ -e ./star_bird-k3s-*.tar.gz ] ; then \
		echo "Removing existing star_bird-k3s-*.tar.gz" ; \
		rm ./star_bird-k3s-*.tar.gz ; \
	else \
		echo "No existing star_bird-k3s-*.tar.gz found" ; \
	fi

build:
	ansible-galaxy collection build
