Generate [Mojolicious][] applications through [skfold][].

# INSTALLATION

This should be all that's needed:

```
mkdir -p ~/.skfold/modules
cd ~/.skfold/modules
git clone https://github.com/polettix/skfold-module-mojo.git mojo
```

Using the Docker image might require that some additional mounting is done to
see the directory inside the container.

# COPYRIGHT & LICENSE

The contents of this repository are licensed according to the Apache
License 2.0 (see file `LICENSE` in the project's root directory):

>  Copyright 2022 by Flavio Poletti
>
>  Licensed under the Apache License, Version 2.0 (the "License");
>  you may not use this file except in compliance with the License.
>  You may obtain a copy of the License at
>
>      http://www.apache.org/licenses/LICENSE-2.0
>
>  Unless required by applicable law or agreed to in writing, software
>  distributed under the License is distributed on an "AS IS" BASIS,
>  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
>  See the License for the specific language governing permissions and
>  limitations under the License.
>
>  Dedicated to the loving memory of my mother.

[Mojolicious]: https://metacpan.org/pod/Mojolicious
[skfold]: https://github.com/polettix/skfold
