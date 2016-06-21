Puppet::Type.newtype(:r8_export_variable) do
  @doc = "r8 export variable content"

  ensurable

  newparam(:name) do
    desc "component and attribute name in dot notation"

    validate do |value|
      unless value =~ /.*::.*/
        raise ArgumentError, "name attribute: #{value} is in invalid format, should be in <component>::<attribute> format"
      end
    end
  end

  newparam(:content) do
    desc "variable content to store in specific attribute"
  end
end