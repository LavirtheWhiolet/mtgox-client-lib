require 'mtgox'

MtGox.instance.virtual_client("#{ENV["HOME"]}/.virtual-mtgox-account").
  run_as_app()
