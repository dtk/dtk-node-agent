define r8::export_variable(
  $content = undef,
) {
  r8_export_variable { $name:
    name => $name,
    content => $content,
    ensure => present,
  }
}