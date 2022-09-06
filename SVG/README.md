# Convert SVG to PNG - librsvg

## install librsvg
`% brew install librsvg`

## lookup version
`% rsvg-convert --version`

## convert svg to png
`% rsvg-convert -b <color> -w <length> -h <length> <input path> > <output path>`

#### e.g.
`% rsvg-convert -b orange -w 652 -h 652 /Users/gavinxiang/Desktop/Ornament_Icon_Export/SVG/Bell\-\ selected.svg > /Users/gavinxiang/Desktop/Ornament_Icon_Export/SVG/Bell\-\ selected_orange_bg.png`

## help
```
~ rsvg-convert --help
rsvg-convert version 2.54.5
Convert SVG files to other image formats

USAGE:
    rsvg-convert [FLAGS] [OPTIONS] [FILE]...

FLAGS:
    -?, --help                  Prints help information
    -a, --keep-aspect-ratio     Preserve the aspect ratio
        --keep-image-data       Keep image data
        --no-keep-image-data    Do not keep image data
    -u, --unlimited             Allow huge SVG files
    -v, --version               Prints version information

OPTIONS:
    -l, --accept-language <languages>    Languages to accept, for example "es-MX,de,en" [default uses language from the
                                         environment]
    -b, --background-color <color>       Set the background color using a CSS color spec
    -i, --export-id <object id>          SVG id of object to export [default is to export all objects]
    -f, --format <format>                Output format [default: png]  [possible values: Png, Pdf, Ps, Eps, Svg]
        --left <length>                  Distance between left edge of page and the image [defaults to 0]
    -o, --output <output>                Output filename [defaults to stdout]
        --page-height <length>           Height of output media [defaults to the height of the SVG]
        --page-width <length>            Width of output media [defaults to the width of the SVG]
    -d, --dpi-x <number>                 Pixels per inch [default: 96]
    -p, --dpi-y <number>                 Pixels per inch [default: 96]
    -w, --width <length>                 Width [defaults to the width of the SVG]
    -h, --height <length>                Height [defaults to the height of the SVG]
    -s, --stylesheet <filename.css>      Filename of CSS stylesheet to apply
        --top <length>                   Distance between top edge of page and the image [defaults to 0]
    -z, --zoom <number>                  Zoom factor
    -x, --x-zoom <number>                Horizontal zoom factor
    -y, --y-zoom <number>                Vertical zoom factor

ARGS:
    <FILE>...    The input file(s) to convert
```
