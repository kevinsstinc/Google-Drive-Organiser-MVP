# documents

an ios app that uses ai to make google drive less messy.

the whole idea is pretty simple:

google drive is useful, but after a while it just turns into a giant pile of random pdfs, screenshots, school work.

documents well, tries to fix that.

instead of manually making folders and moving everything yourself, you just pick a few main folders you actually care about.

for example:

```text
school
projects
personal
design
```

then gemini looks through your drive files, figures out what they are, and sorts them for you.

it can also make subfolders when it makes sense.

so instead of this:

```text
my drive
├── bio notes.pdf
├── physics ws 4.pdf
├── taskstack logo.svg
├── random screenshot.png
├── math homework.pdf
├── project pitch.pdf
└── IMG_4821.jpg
```

you'd get something more like:

```text
school
├── biology
│   └── bio notes.pdf
│
├── physics
│   └── physics ws 4.pdf
│
└── math
    └── math homework.pdf

projects
└── taskstack
    └── project pitch.pdf

design
└── taskstack
    └── taskstack logo.svg

personal
├── random screenshot.png
└── IMG_4821.jpg
```

## why i made this

i use google drive a lot and i realised most of my files basically just sit wherever they landed.

i could organise everything manually, but i know i'm not gonna keep doing that every time i upload something.

so i wanted to make something where you organise your drive once at a high level, then let the app deal with the boring part.

the goal isn't really to replace google drive.

it's more like giving google drive an actual brain for organising stuff.

## how it works

the basic flow is:

```text
connect google drive

        ↓

pick your main folders

        ↓

documents scans your files

        ↓

gemini figures out what belongs where

        ↓

it creates useful subfolders

        ↓

you preview the changes

        ↓

documents organises everything
```

i don't want the app to just randomly start moving everything the second it gets access to your drive, so the idea is that you can see what it's planning first.

something like:

```text
physics energy.pdf

move to:
school / physics

because:
appears to be a physics worksheet about energy
```

then you can approve it.

## ai sorting

the main thing documents does differently is that it doesn't only look at filenames.

because filenames are usually terrible.

something called:

```text
worksheet.pdf
```

could be literally anything.

so the app can use whatever information it can get from the file, like:

* filename
* file type
* metadata
* text inside the file
* where it currently is
* other related files nearby

then gemini decides where it probably belongs.

so even if the filename is useless, the app can still hopefully understand what the file actually is.

## folders

you don't have to make every single folder yourself.

you could just start with:

```text
school
projects
personal
design
```

and documents could turn `school` into:

```text
school
├── biology
├── chemistry
├── physics
├── math
└── humanities
```

based on what files you actually have.

same thing for projects.

if it finds a bunch of files related to the same thing, it could make a folder for it.

```text
projects
├── taskstack
├── documents
├── hackathon
└── website redesign
```

## search

i also want search to be way less dependent on remembering exact filenames.

instead of searching:

```text
S3_Physics_Energy_Worksheet_4.pdf
```

you should eventually be able to type something like:

```text
the physics worksheet about kinetic energy
```

and get the right file.

basically semantic search, but for your drive.

## tech

the app is being built natively for ios.

```text
swift
swiftui
google drive api
google oauth
gemini api
```

roughly:

```text
google drive
     ↓
get files
     ↓
get useful file info
     ↓
send context to gemini
     ↓
classify files
     ↓
generate folder structure
     ↓
show preview
     ↓
apply changes
```

## stuff i still want to add

* [ ] smarter search
* [ ] undo organising
* [ ] organisation history
* [ ] file previews
* [ ] duplicate detection
* [ ] better folder suggestions
* [ ] drag and drop
* [ ] teach the ai when it gets something wrong
* [ ] remember how you organise things
* [ ] ipad support
* [ ] maybe onedrive / dropbox support later

## safety

letting ai move your files around can go very wrong very fast lol

so documents isn't supposed to delete anything.

the flow should always be more like:

```text
analyse
↓
suggest
↓
preview
↓
confirm
↓
move
```

## getting started

you'll need:

* xcode
* an ios device or simulator
* a google cloud project
* google drive api enabled
* google oauth setup
* a gemini api key

clone the repo:

```bash
git clone <repo-url>
cd Documents
```

then open it in xcode:

```bash
open Documents.xcodeproj
```

you'll also need to add your own google / gemini credentials.

don't commit your api keys pls, i've learnt my lessons

## current status

still very much a work in progress.

right now i'm mainly working on:

* the file browser
* folder ui
* google drive integration
* ai sorting
* folder generation
* search

some stuff might be broken, unfinished or randomly change because i'm still figuring out how i want the app to work.

## why "documents"

honestly i just needed a name when i started the project.

it'll probably change.

well maybe.

## goal

make managing files feel less like managing files.

that's basically it.
