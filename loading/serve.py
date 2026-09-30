import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

port = int(sys.argv[1]) if len(sys.argv) > 1 else 27080
root = os.path.dirname(os.path.abspath(__file__))
log_path = os.path.join(os.environ.get("TEMP", "."), "relapse_loading_access.log")


class Handler(SimpleHTTPRequestHandler):
	def __init__(self, *args, **kwargs):
		super().__init__(*args, directory=root, **kwargs)

	def log_message(self, fmt, *args):
		# A dead stderr must not abort the response. The loading page is white
		# when this process accepts the socket and then sends nothing.
		try:
			line = "%s - %s\n" % (self.log_date_time_string(), fmt % args)
			with open(log_path, "a", encoding="utf-8") as handle:
				handle.write(line)
		except OSError:
			pass


class Server(ThreadingHTTPServer):
	daemon_threads = True
	allow_reuse_address = True


Server(("0.0.0.0", port), Handler).serve_forever()
