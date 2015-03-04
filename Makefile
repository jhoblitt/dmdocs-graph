TEMPFILE := $(shell mktemp -u)

all: images/dmdocs.png images/collection-2511.png

images/%.png : %.dot
	unflatten $< -o ${TEMPFILE} -l 10 -c 10
	dot -Tpng ${TEMPFILE} -o $@
	rm ${TEMPFILE}

clean:
	rm *.png
