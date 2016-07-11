require 'fileutils'

Puppet::Type.type(:r8_export_variable).provide(:default) do
  desc "r8 export variable"

  def create
    name = resource[:name]
    content = resource[:content]
    if name =~ /(^.+)::(.+$)/
      component = $1
      attribute = $2
      if content = (content == '***' ? scope.lookupvar(name) : content)
        p = Thread.current[:exported_variables] ||= Hash.new
        (p[component] ||= Hash.new)[attribute] = content
        File.open('/tmp/dtk_exported_variables', 'w') { |f| f.write(Marshal.dump(p)) }
      end
    end
  end

  def destroy
    FileUtils.rm_rf("/tmp/dtk_exported_variables")
  end

  def exists?
    
  end
end