require 'requirements'
require 'facets/string/indent'


class String
  
  def indent_to(required_indentation_level, padding_char = ' ')
    return padding_char * required_indentation_level if self.empty?
    current_indentation_level = self.lines.map { |line| line[/^#{padding_char}*/].length }.min
    self.indent(required_indentation_level - current_indentation_level, padding_char)
  end
  
end
