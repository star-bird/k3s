all: clean build
clean:
	rm ./star_bird-k3s-*.tar.gz ;

build:
	ansible-galaxy collection build
