.PHONY: FORCE all tests auto-promote clean

all: FORCE
	dune build --root=. @install

tests: FORCE
	dune runtest --root=.

auto-promote: FORCE
	dune runtest --root=. --auto-promote

clean: FORCE
	dune clean
