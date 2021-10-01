.PHONY: FORCE

all: FORCE
	dune build --root=. @install
