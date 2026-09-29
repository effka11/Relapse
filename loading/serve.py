import os
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

port = int(sys.argv[1]) if len(sys.argv) > 1 else 27080
root = os.path.dirname(os.path.abspath(__file__))
handler = partial(SimpleHTTPRequestHandler, directory=root)


class Server(ThreadingHTTPServer):
	daemon_threads = True
	allow_reuse_address = True


Server(("0.0.0.0", port), handler).serve_forever()
