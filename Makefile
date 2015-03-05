TEMPFILE := $(shell mktemp -u)

all: images/dmdocs.png images/collection-2511.png images/collection-2511-recursive.png

collection-2511.dot:
	bundle exec ./docucrawl.rb --seed collection-2511.yaml --output collection-2511.dot

collection-2511-recursive.dot:
	bundle exec ./docucrawl.rb --seed collection-2511.yaml --output collection-2511-recursive.dot --recursive

images/%.png : %.dot
	unflatten $< -o ${TEMPFILE} -l 10 -c 10
	dot -Tpng ${TEMPFILE} -o $@
	rm ${TEMPFILE}

clean:
	rm *.png
