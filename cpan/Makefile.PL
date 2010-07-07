use 5.008001;
use strict;
use inc::Module::Install;

name            'App-SocialCalc-Multiplayer';
author          '唐鳳 <cpan@audreyt.org>';
license         'CPAL';
repository      'http://github.com/audreyt/socialcalc';
all_from        'Multiplayer.pm';
readme_from     'Multiplayer.pm';
requires        'Web::Hippie';
requires        'JSON::XS';
requires        'Twiggy';
requires        'Text::MicroTemplate::File';
requires        'Path::Class';
requires        'File::ShareDir';

install_share   'socialcalc';
install_script  'socialcalc-multiplayer.pl';

sign; WriteAll;

1;
