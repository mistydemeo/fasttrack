require 'fasttrack/exempi/namespaces'

module Fasttrack
  # Populates a hash with the namespace values from Exempi::Namespaces
  NAMESPACES = {}
  Exempi::Namespaces.constants.each do |const|
    name = const.to_s.match(/XMP_NS_(.+)/)[1].downcase.to_sym
    uri = Exempi::Namespaces.const_get const
    NAMESPACES[name] = uri
  end
end