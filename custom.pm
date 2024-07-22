package SKFold::Custom;
use strict;
use warnings;
use Path::Tiny;

sub adapt_module_configuration {
   my ($config) = @_;

   $config->{opts}{has_db} = 1 if $config->{opts}{has_minion};
   $config->{opts}{has_controller} = 1
      if $config->{opts}{has_authentication};

   my $tdir = path($config->{target_dir});
   $config->{target_dir} =~ s{::}{-}gmxs;

   my $main_module = $config->{target};
   my %common_options = (
      distro_name => $config->{target_dir},
      main_module => $main_module,
      other_modules => \my @other_modules,
      all_modules => \my %all_modules,
      invoke_opts => $config->{opts},
   );

   my (%pods, @files, @directories);
   ITEM:
   for my $item (@{$config->{files}}) {
      my %model = %$item;
      if ($model{destination} eq '*module') {
         next ITEM if $model{condition} && ! $config->{opts}{$model{condition}};
         my $module = $main_module . ($model{suffix} // '');
         push @other_modules, $module if $module ne $main_module;
         $all_modules{$model{add_key}} = $module if $model{add_key};

         (my $path = "lib/$module.pm") =~ s{::}{/}gmxs;
         push @files, {
            %model,
            destination => $path,
            opts => {
               %{$model{opts} || {}},
               %common_options,
               module => $module,
               filename => $path,
            },
         };

         $path =~ s{\.pm$}{.pod}mxs;
         $pods{$path} = $module;

         my $dir = path($path)->parent;
         while ($dir ne '.') {
            unshift @directories, {
               destination => $dir->stringify,
               mode => $model{dmode},
            };
            $dir = $dir->parent;
         }
      }
      elsif ($model{destination} eq '*pod') {
         push @files, map{
            {
               %model,
               destination => $_,
               opts => {
                  %{$model{opts} || {}},
                  %common_options,
                  module => $pods{$_},
                  filename => $_,
               },
            }
         } sort { $a cmp $b } keys %pods;
      }
      elsif ($model{destination} =~ m{\A \*skip}mxs) {}
      else {
         $model{opts} = {%common_options, %{$model{opts} || {}}};
         if (exists $model{source}) {
            push @files, \%model;
         }
         else {
            push @directories, \%model;
         }
      };
   }

   $config->{files} = [@directories, @files];
}



1;

__END__




   my (%directories, %modules, %pods);


   my $controller_module = $main_module . '::Controller';
   my $basic_routes_module = $controller_module . '::Basic';
   my $minion_module = $main_module . '::Minion';
   my $basic_actions_module = $minion_module . '::Basic';


   my @other_modules;# FIXME = @{$config->{args}};

   my (%directories, %modules, %pods);
   for my $module ($main_module, @other_modules) {
      next if exists $modules{$module};
      (my $path = "lib/$module.pm") =~ s{::}{/}gmxs;
      my $dir = path($path)->parent;
      while ($dir ne '.') {
         $directories{$dir} = 1;
         $dir = $dir->parent;
      }
      $modules{$path} = $module;
      $path =~ s{\.pm$}{.pod}mxs;
      $pods{$path} = $module;
   }

   my (@files, @directories);
   for my $item (@{$config->{files}}) {
      my %model = %$item;
      if ($model{destination} eq '*module') {
         push @directories, map {
            {
               destination => $_,
               mode => $model{dmode},
            }
         } sort { length $a <=> length $b } keys %directories;
         push @files, map{
            {
               %model,
               destination => $_,
               opts => {
                  %{$model{opts} || {}},
                  %common_options,
                  module => $modules{$_},
                  filename => $_,
               },
            }
         } keys %modules;
      }
      elsif ($model{destination} eq '*pod') {
         push @files, map{
            {
               %model,
               destination => $_,
               opts => {
                  %{$model{opts} || {}},
                  %common_options,
                  module => $pods{$_},
                  filename => $_,
               },
            }
         } keys %pods;
      }
      else {
         $model{opts} = {%common_options, %{$model{opts} || {}}};
         if (exists $model{source}) {
            push @files, \%model;
         }
         else {
            push @directories, \%model;
         }
      };
   }

   $config->{files} = [@directories, @files];
};

1;
