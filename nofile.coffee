kit = require 'nokit'
kit.require 'drives'

module.exports = (task, option) ->

	task 'default build', ['doc', 'code']

	task 'doc', ['code'], 'build doc', ->
		size = kit.statSync('lib/yaku.min.js').size / 1024
		kit.warp 'src/*.js'
		.load kit.drives.comment2md {
			tpl: 'docs/readme.jst.md'
			doc: {
				size: size.toFixed 1
			}
		}
		.run()

	addLicense = (str) ->
		{ version } = kit.require './package', __dirname
		return """
		/*
		 Yaku v#{version}
		 (c) 2015 Yad Smood. http://ysmood.org
		 License MIT
		*/\n
		""" + str

	task 'code', ['lint'], 'build source code', ->
		kit.warp 'src/*.js'
		.load (f) ->
			if f.dest.name == 'yaku'
				f.set addLicense f.contents
		.run 'lib'
		.then ->
			kit.spawn 'uglifyjs', ['-mc', '-o', 'lib/yaku.min.js', 'lib/yaku.js']

	task 'lint', 'lint js files', ->
		kit.spawn 'eslint', ['src/*.js']

	task 'all', ['lint'], 'bundle all', ->
		process.env.NODE_ENV = 'production'
		kit.spawn 'webpack'

	option '--debug', 'run with remote debug server'
	option '--port <8219>', 'remote debug server port', 8219
	task 'lab l', 'run and monitor "test/lab.coffee"', (opts) ->
		args = ['test/lab.coffee']

		if opts.debug
			kit.log opts.debug
			args.splice 0, 0, '--nodejs', '--debug-brk=' + opts.port

		kit.monitorApp { bin: 'coffee', args }

	option '--grep <pattern>', 'run test that match the pattern', '.'
	task 'test', 'run Promises/A+ tests', (opts) ->
		if opts.grep == '.'
			require './test/basic'

		setTimeout ->
			require('./test/compliance.coffee') {
				grep: opts.grep
			}
		, 1000

	option '--sync', 'sync benchmark'
	task 'benchmark'
	, 'compare performance between different libraries'
	, (opts) ->
		process.env.NODE_ENV = 'production'
		os = require 'os'

		console.log """
			Node #{process.version}
			OS   #{os.platform()}
			Arch #{os.arch()}
			CPU  #{os.cpus()[0].model}
			#{kit._.repeat('-', 80)}
		"""

		paths = kit.globSync 'benchmark/*.coffee'

		sync = if opts.sync then 'sync' else ''
		kit.async paths.map (path) -> ->
			kit.spawn 'coffee', [path, sync]

	task 'clean', 'Clean temp files', ->
		kit.remove '{.nokit,lib,.coffee,.nobone}'

	option '--browserPort <8227>', 'browser test port', 8227
	task 'browser', 'Unit test on browser', (opts) ->
		{ flow, select, body } = kit.require('proxy')

		app = flow()
		app.push(
			body()

			select '/log', ($) ->
				kit.logs $.reqBody + ''
				$.next()

			select '/', ($) ->
				$.body = kit.readFile 'lib/test-basic.js'
				.then (js) -> """
					<html>
						<body></body>
						<script>#{js}</script>
					</html>"""
		)

		kit.spawn 'webpack', ['--progress', '--watch']

		kit.sleep(2000).then ->
			app.listen opts.browserPort
		.then ->
			kit.log 'Listen ' + opts.browserPort
			kit.xopen 'http://127.0.0.1:' + opts.browserPort