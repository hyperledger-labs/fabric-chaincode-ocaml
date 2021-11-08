.PHONY: FORCE all tests

all: FORCE
	dune build --root=. @install

tests: FORCE
	dune runtest --root=.
