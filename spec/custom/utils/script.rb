# Custom options for mspec-run
#
class MSpecRun
  def custom_options(options)
    options.compiler
    options.parser
  end
end

# Custom options for mspec-ci
#
class MSpecCI
  def custom_options(options)
    options.compiler
    options.parser
  end
end

# Custom options for mspec-tag
#
class MSpecTag
  def custom_options(options)
    options.compiler
    options.parser
  end
end
