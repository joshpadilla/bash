import urllib.request

urllist = ("http://url.com/archive.zip?key=7UCxcuCzFpYeu7tz18JgGZFAAgXQ2sop",
            http://cs.slu.edu/~goldwasser/publications/python2cpp.pdf
	    http://pages.physics.cornell.edu/~myers/teaching/ComputationalMethods/LectureNotes/Intro_to_Python.pdf
	    https://www.fer.unizg.hr/_download/repository/p02-python.pdf
	    http://mcsp.wartburg.edu/zelle/python/sigcse-slides.pdf
	    http://users.fs.cvut.cz/ivo.bukovsky/PVVR/prace_studentu/Python_for_DBS.pdf
	    http://www.maths.manchester.ac.uk/~scoban/python_lecture_2_psbc.pdf
	    http://www.dlr.de/sc/Portaldata/15/Resources/dokumente/PyHPC2013/submissions/pyhpc2013_submission_5.pdf
	    http://srl.geoscienceworld.org/content/85/4/905.full.pdf
	    http://www.reportlab.com/docs/reportlab-userguide.pdf
	    http://brochure.getpython.info/media/releases/psf-python-brochure-vol.-i-final-download.pdf
	    http://babel.pocoo.org/docs/babel-docs.pdf
	    http://mike.pirnat.com/static/joy-of-logging.pdf
	    http://download.logilab.org/pub/talks/XMLTutorial.pdf
	    http://twistedmatrix.com/documents/current/core/howto/book.pdf
	    http://www.engr.ucsb.edu/~shell/che210d/numpy.pdf
	    http://0b4af6cdc2f0c5998459-c0245c5c937c5dedcca3f1764ecc9b2f.r43.cf2.rackcdn.com/9345-login1210_beazley.pdf
	    http://www2.imm.dtu.dk/pubdb/views/edoc_download.php/6661/pdf/imm6661.pdf
	    http://peadrop.com/slides/mp5.pdf
	    http://marvin.cs.uidaho.edu/Teaching/CS270/pythonLibrary.pdf
	    http://www.cse.msstate.edu/~tjk/teaching/python/materials/03libraries.pdf
	    http://www.curiousvenn.com/wp-content/uploads/2012/08/Tutorial2.pdf
	    http://www.yelsterdigital.com/jobs/Job-Offer-Python_EN.pdf
	    http://calcul.math.cnrs.fr/Documents/Ecoles/2010/cours_multiprocessing.pdf
	    http://slav0nic.org.ua/static/books/python/net_thread/threads-and-processes.pdf
	    http://software-carpentry.org/v4/python/lib.pdf
	    http://bottlepy.org/docs/dev/bottle-docs.pdf
	    http://csc.ucdavis.edu/~chaos/courses/nlp/Software/NumPyBook.pdf
	    http://downloads.mysql.com/docs/connector-python-en.a4.pdf
	    http://effbot.org/media/downloads/librarybook-core-modules.pdf
	    https://media.readthedocs.org/pdf/python-packaging-user-guide/latest/python-packaging-user-guide.pdf
	    http://www.rafekettler.com/magicmethods.pdf
	    ftp://ftp.ntua.gr/mirror/python/pycon/papers/largedata.pdf
	    "another",
	    "yet another",
	    "etc")

filename = "~/test.zip"
destinationPath = "C:/test"

for url in urllist:
	try:
		urllib.request.urlretrieve(url,filename)
	except ValueError:
		continue
	sourceZip = zipfile.ZipFile(filename, 'r')

	for name in sourceZip.namelist():
		sourceZip.extract(name, destinationPath)
	sourceZip.close()
	break

#!/bin/bash
#
#clear
#echo Downloading $1
#echo
#filename=`echo $2 | sed -e "s/ /\\\ /g"`
#echo $filename
#echo eval curl -# -C - -o $filename $1
#
#file="filename"
#
#while read line
#do 
#	  outfile=$(echo $line | awk 'BEGIN { FS = "/" } ; {print $NF}')
#	    curl -o "$outfile.html" "$line"
#    done < "$file"
#import pycurl
#c = pycurl.Curl()
#c.setopt(pycurl.URL, "http://curl.haxx.se")
#m = pycurl.CurlMulti()
#m.add_handle(c)
#while 1:
#	ret, num_handles = m.perform()
#	if ret != pycurl.E_CALL_MULTI_PERFORM: break
#while num_handles:
#	apply(select.select, m.fdset() + (1,))
#	while 1:
#	ret, num_handles = m.perform()
#	if ret != pycurl.E_CALL_MULTI_PERFORM: break
