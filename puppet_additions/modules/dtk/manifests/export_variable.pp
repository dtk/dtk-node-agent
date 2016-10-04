define dtk::export_variable(
  $content = undef,
) {
  dtk_export_variable { $name:
    name => $name,
    content => $content,
    ensure => present,
  }
}
