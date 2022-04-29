### SOURCE: https://jose-elias-alvarez.medium.com/testing-neovim-plugins-with-plenary-nvim-2464fb058448
### AUTHOR: Jose Elias Alvarez


# Testing Neovim plugins with Plenary.nvim

   Test, test, and test again
   Neovim logo courtesy of [6]Wikipedia.

   Writing Neovim plugins in Lua is fun. Like all projects,
   though, plugins tend to grow, and the more code your plugin
   contains, the more you’ll run into bugs or unexpected
   interactions. That’s where testing comes in.

   Of the available Lua testing libraries, the best option
   for Neovim plugins is the test harness bundled into
   [7]plenary.nvim. Along with other utilities, Plenary includes
   a simplified version of the unit testing framework [8]busted
   with options to make testing Neovim plugins simpler.

   Plenary itself is still under development, and the
   documentation isn’t yet finalized, so I want to share what
   I’ve learned from writing and maintaining test coverage for
   my Lua plugins so you can get straight to testing.

## Setup

   For this article, we’ll be working on uppercase.nvim, a
   fake plugin that defines a command to capitalize the text in
   the current buffer. (Please ignore the existence of gU.)

   Let’s set up the project structure and create the files
   we’ll be using:
```
cd ~
mkdir -p uppercase.nvim/lua/uppercase uppercase.nvim/test
cd uppercase.nvim
touch lua/uppercase/init.lua test/init_spec.lua
touch Makefile test/minimal.vim
```

   You’ll then want to add the following code for our plugin to
   lua/uppercase/init.lua:
```
-- init.lua
local M = {}
-- convert a string to uppercase
local to_uppercase = function(text)
    assert(type(text) == "string", "to_uppercase requires a string")
    return text:upper()
end
M.to_uppercase = to_uppercase
-- get the content of the current buffer, convert each line to uppercase, and re
place
M.buffer_to_uppercase = function()
    for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        local converted = to_uppercase(line)
        vim.api.nvim_buf_set_lines(0, i - 1, i, false, { converted })
    end
end
-- set up a command for easier uppercasing
M.setup = function()
    vim.cmd('command! ToUppercase lua require("uppercase").buffer_to_uppercase()
')
end
return M
```

   If you’re unclear about what any of the Lua code above is
   doing, check out the corresponding entry in :help.

## Setting up Plenary

   Make sure you have Plenary installed. You may not need to do
   anything, since it’s a dependency of popular plugins like
   [9]telescope.nvim. If not, follow your plugin manager’s
   instructions to install it.

   For convenience, we’ll define a keymap to run tests in the
   current file. Feel free to change the key, but note that
   you’ll probably want to delete this by the end of the
   guide, so don’t stress:
```
" vimscript
nmap <Leader>t <Plug>PlenaryTestFile-- lua
vim.api.nvim_set_keymap("n", "<Leader>t", "<Plug>PlenaryTestFile", {})
```

Adding our plugin

   Modern plugin managers like [10]vim-plug and [11]packer.nvim
   can manage local plugins, so let’s take advantage of that:
```
" vim-plug
Plug '~/uppercase.nvim'-- packer
use("~/uppercase.nvim")
```

   We’ll also add the following line to set up our plugin
   (choose the right one for your config language):
```
" vimscript
lua require("uppercase").setup()-- lua
require("uppercase").setup()
```

   Restart Neovim or resource your configuration, run your
   plugin manager’s command to install the new plugin, then
   open a file and run :ToUppercase. You should see something
   like this: Beautiful, right?

   We now have an entire plugin to replicate what Vim could
   already do with gggUG... but in Lua. We're true Neovim plugin
   developers!

## Testing

   The plugin seems to work, but we want to make sure it keeps
   working as we add more and more functionality (lowercasing?
   camelCasing?). That’s what tests are for.

   Open up test/init_spec.lua and add the following code:
```
-- init_spec.lua
local uppercase = require("uppercase")
describe("uppercase", function()
    describe("to_uppercase", function()
        it("should convert lowercase text to uppercase", function()
            local text = "some text"
            local converted = uppercase.to_uppercase(text)
            assert.are.equal(converted, "SOME TEXT")
        end)
    end)
end)
```

   After importing our plugin, we start with two describe
   blocks, which help structure and... describe our tests. Each
   block accepts two arguments, a description and a callback. We
   generally want one block for the whole file and a block for
   each function, but we can nest blocks to break up tests as
   necessary.

   We then have an it block, which contains our actual tests.
   Like describe blocks, it blocks take a description and a
   callback. If the callback throws an error, the test fails,
   and if not, the test succeeds.

   Our test follows the typical arrange-act-assert structure.
   We declare a string, pass it into the function we want to
   test, and assert against the output. assert.are.equal comes
   from [12]luassert, a library that extends the built-in
   assert function to provide helpers. We'll go over some other
   assertions in this article, but you can check out the full
   list on the repository.

   Note that when running tests, Plenary automatically injects
   the library into the global scope, so we don’t need to
   require it.

   Functionally, the code above achieves the same result as this:
```
it("should convert lowercase text to uppercase", function()
    local text = "some text"
    local converted = uppercase.to_uppercase(text)
    if converted ~= "SOME TEXT" then
        error("expected SOME TEXT, received " .. converted)
    end
end)
```

   But luassert makes our lives easier by bundling common
   assertions and providing better feedback when tests fail, as
   we’ll see soon.

   Anyways, let’s run our test and see what it looks like. You
   can use the keybinding you defined earlier or this unwieldy
   command:

```
:lua require('plenary.test_harness').test_directory(vim.fn.expand("%:p"))
```

   You should see a terminal window pop up containing the following test
   output:
```
   Success!
```

   Our test passed. If you’re unfamiliar with Neovim’s
   terminal buffers, you may wonder how you can exit this
   window. The answer is <C-\><C-n>, which puts you back in
   normal mode and lets you quit with:q.

   What does it look like when a test fails? Let’s try it:
```
-- init_spec.lua
local uppercase = require("uppercase")
describe("uppercase", function()
    describe("to_uppercase", function()
        it("should convert lowercase text to uppercase", function()
            local text = "some text"
            local converted = uppercase.to_uppercase(text)
            assert.are.equal(converted, "SOME TEXT")
        end)
        it("should fail", function()
            local text = "some text"
            local converted = uppercase.to_uppercase(text)
            assert.are.equal(converted, "not uppercased")
        end)
    end)
end)

```
   Failure!

   Our test fails, and luassert gives us a nice message
   describing what we expected vs. what we received. The bottom
   of the output also shows the exit code, where 1 indicates
   that at least 1 test failed and 0 indicates that all tests
   succeeded.

   Let’s add some more tests to be sure our function works as
   expected:

```
local uppercase = require("uppercase")
describe("uppercase", function()
    describe("to_uppercase", function()
        it("should convert lowercase text to uppercase", function()
            local text = "some text"
            local converted = uppercase.to_uppercase(text)
            assert.are.equal(converted, "SOME TEXT")
        end)
        it("should convert mixed case text to uppercase", function()
            local text = "sOMe TexT"
            local converted = uppercase.to_uppercase(text)
            assert.are.equal(converted, "SOME TEXT")
        end)
        it("should not convert already uppercase text", function()
            local text = "SOME TEXT"
            local converted = uppercase.to_uppercase(text)
            assert.are.equal(converted, "SOME TEXT")
        end)
    end)
end)
```

   Back to success!

## Error handling

   If you look at our plugin’s code, you’ll see that we do
   a typecheck on the text passed into to_uppercase. How can we
   check that the typecheck works? We'll look at two solutions,
   one with luassert and one without:

```
-- luassert solution
local uppercase = require("uppercase")
describe("uppercase", function()
    describe("to_uppercase", function()
        it("should throw if text is not a string", function()
            assert.has.errors(function()
                uppercase.to_uppercase({ "not a string" })
            end)
        end)
    end)
end)
```

   assert.has.errors is a special assertion that accepts a
   callback. If that callback throws an error, the test passes.
   It's convenient, but we can put together another solution
   with pcall if we want to check what's in the error, too:

```
-- native solution
local uppercase = require("uppercase")
describe("uppercase", function()
    describe("to_uppercase", function()
        it("should throw if text is not a string", function()
            local ok, err = pcall(uppercase.to_uppercase, { "not a string" })
            assert.falsy(ok)
            assert.truthy(err)
            assert.truthy(err:find("requires a string"))
        end)
    end)
end)
```

   We used two new assertions, assert.falsy, which requires a
   nil or false value, and assert.truthy, which requires a value
   that is not nil or false, to check that the function call
   threw an error and that the error message contains what we
   expect.

   Note: luassert lets us define custom assertions, but I prefer
   to avoid them and use native solutions to avoid confusing
   other developers.

## Cleaning up our environment

   If we make a mistake and setup stops working, users who rely on
   :ToUppercase will feel confused and angry, and you don't want that in
   your GitHub notifications. Let's make sure that it works in a new
   describe block:

```
local uppercase = require("uppercase")
describe("uppercase", function()
    describe("setup", function()
        it("should define the :ToUppercase command", function()
            uppercase.setup()
            assert.truthy(vim.fn.exists(":ToUppercase") > 0)
        end)
    end)
end)
```

   Remember that in the hellscape that is Vimscript, a return
   value of 0 meansfalse and non-zero return values mean some
   variant of true.

   Seems okay, right? But there’s a catch. What do you expect
   will happen when we run these two tests?

```
local uppercase = require("uppercase")
describe("uppercase", function()
    describe("setup", function()
        it("should define the :ToUppercase command", function()
            uppercase.setup()
            assert.truthy(vim.fn.exists(":ToUppercase") > 0)
        end)
        it("should not have defined a :ToUppercase command", function()
            assert.truthy(vim.fn.exists(":ToUppercase") == 0)
        end)
    end)
end)
```

## Wait, what?

   The second test failed because :ToUppercase exists. But why?
   Plenary runs these tests in a single headless instance of
   Neovim, so if we've defined the command once, it'll persist
   throughout the lifetime of the instance. We want to isolate
   our tests, though, and make sure we're starting each test
   with a clean environment. For that, we'll use after_each to
   tear down our environment:

```
local uppercase = require("uppercase")
describe("uppercase", function()
    describe("setup", function()
        after_each(function()
            vim.cmd("silent! comclear")
        end)
        it("should define the :ToUppercase command", function()
            uppercase.setup()
            assert.truthy(vim.fn.exists(":ToUppercase") > 0)
        end)
        it("should not have defined a :ToUppercase command", function()
            assert.truthy(vim.fn.exists(":ToUppercase") == 0)
        end)
    end)
end)
```

   after_each runs after each test in its parent describe block.
   Here, we call:comclear to make sure we delete any commands
   we've created, and our test passes. Plenary also provides a
   before_each helper that runs before each test and is useful
   for setting up the environment.

## The main event

   Alright, we’re ready to test :ToUppercase. Remember that
   each tests starts with a fresh Neovim instance, so we need to
   follow these steps:

    1. Set up our plugin;
    2. Add some text to the current buffer;
    3. Run our command;
    4. Check the buffer’s content and make sure it’s in
uppercase; and
    5. Reset the environment.

   Our plugin is simple, but since Neovim is a text editor, this
   same pattern applies to a good number of plugins. First,
   let’s make a new describe block for the command:

```
local uppercase = require("uppercase")
describe("uppercase", function()
    describe(":ToUppercase", function()
        before_each(function()
            uppercase.setup()
        end)
        after_each(function()
            vim.cmd("silent! comclear")
        end)
    end)
end)
```

   We use before_each and after_each to set up and tear down our
   environment for this block, and since we've already tested
   to_uppercase and setup, we can feel confident that everything
   will work.

   That’s step 1. Let’s take care of steps 2–4 in one go.
   There’s more than one way to add text to a buffer, but
   we’ll use Neovim’s API for consistency:

```
local uppercase = require("uppercase")
describe("uppercase", function()
    describe(":ToUppercase", function()
        before_each(function()
            uppercase.setup()
        end)
        after_each(function()
            vim.cmd("silent! comclear")
        end)
        it("should convert buffer text to uppercase", function()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, {
                "line1",
                "line2",
                "line3",
                "line4",
            })
            vim.cmd(":ToUppercase")
            assert.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
                "LINE1",
                "LINE2",
                "LINE3",
                "LINE4",
            })
        end)
    end)
end)
```

   Since two Lua tables are equal only if they refer to the same
   object, we use a new assertion, assert.same, which checks if
   two tables contain the same elements.

   Lastly, we want to make sure our environment is clean, so
   we’ll make sure to clear out the buffer’s content:

```
local uppercase = require("uppercase")
describe("uppercase", function()
    describe(":ToUppercase", function()
        before_each(function()
            uppercase.setup()
        end)
        after_each(function()
            vim.cmd("silent! comclear")
            vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
        end)
        it("should convert buffer text to uppercase", function()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, {
                "line1",
                "line2",
                "line3",
                "line4",
            })
            vim.cmd(":ToUppercase")
            assert.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
                "LINE1",
                "LINE2",
                "LINE3",
                "LINE4",
            })
        end)
    end)
end)
```

   And with that, we’re have a good starting point for our
   tests! Here’s the full test file so far for reference:

```
-- init_spec.lua
local uppercase = require("uppercase")
describe("uppercase", function()
    describe("to_uppercase", function()
        it("should convert lowercase text to uppercase", function()
            local text = "some text"
            local converted = uppercase.to_uppercase(text)
            assert.are.equal(converted, "SOME TEXT")
        end)
        it("should convert mixed case text to uppercase", function()
            local text = "sOMe TexT"
            local converted = uppercase.to_uppercase(text)
            assert.are.equal(converted, "SOME TEXT")
        end)
        it("should not convert already uppercase text", function()
            local text = "SOME TEXT"
            local converted = uppercase.to_uppercase(text)
            assert.are.equal(converted, "SOME TEXT")
        end)
        it("should throw if text is not a string", function()
            local ok, err = pcall(uppercase.to_uppercase, { "not a string" })
            assert.falsy(ok)
            assert.truthy(err)
            assert.truthy(err:find("requires a string"))
        end)
    end)
    describe("setup", function()
        after_each(function()
            vim.cmd("silent! comclear")
        end)
        it("should define the :ToUppercase command", function()
            uppercase.setup()
            assert.truthy(vim.fn.exists(":ToUppercase") > 0)
        end)
    end)
    describe(":ToUppercase", function()
        before_each(function()
            uppercase.setup()
        end)
        after_each(function()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
            vim.cmd("silent! comclear")
        end)
        it("should convert buffer text to uppercase", function()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { "line1", "line2", "lin
e3", "line4" })
            vim.cmd(":ToUppercase")
            assert.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
                "LINE1",
                "LINE2",
                "LINE3",
                "LINE4",
            })
        end)
    end)
end)
```

## Limiting exposure

   One final issue with our tests is that they force us to
   expose to_uppercase. This isn't ideal, since to_uppercase
   isn't part of our API and we don't want users to get angry if
   we have to refactor or remove it in the future.

   One solution is to conditionally expose it using a global
variable:

```
local to_uppercase = ...
local M = {}
if _G._TEST then
    M.to_uppercase = to_uppercase
end
return M
```

   Then in our test file, we can set _G._TEST = true at the top
   of the file to get access to the export. Of course, getting
   around this limitation is trivial, but it at least signals to
   users that this isn't part of the public API.

   A better solution (and the one recommended by the maintainers
   of busted) is to avoid testing local functions in the first
   place:

     We believe the correct way to address [testing local
     functions] is to refactor your code to make it more
     externally testable.

   In fact, we can transfer our tests from to_uppercase and put
   them into the:ToUppercase block instead. This results in less
   exposure, cleans up our code, and brings our tests closer to
   actual user interaction. Here's what that might look like:

```
local uppercase = require("uppercase")
describe("uppercase", function()
    describe(":ToUppercase", function()
        before_each(function()
            uppercase.setup()
        end)
        after_each(function()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
            vim.cmd("silent! comclear")
        end)
        it("should convert lowercase text to uppercase", function()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { "line1", "line2", "lin
e3", "line4" })
            vim.cmd(":ToUppercase")
            assert.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
                "LINE1",
                "LINE2",
                "LINE3",
                "LINE4",
            })
        end)
        it("should convert mixed case text to uppercase", function()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { "LiNe1", "LiNe2", "lIN
E3", "LinE4" })
            vim.cmd(":ToUppercase")
            assert.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
                "LINE1",
                "LINE2",
                "LINE3",
                "LINE4",
            })
        end)
        it("should not convert already uppercase text", function()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { "LINE1", "LINE2", "LIN
E3", "LINE4" })
            vim.cmd(":ToUppercase")
            assert.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
                "LINE1",
                "LINE2",
                "LINE3",
                "LINE4",
            })
        end)
    end)
end)
```

   We’re no longer testing the typecheck in to_uppercase, but
   since the function is no longer exposed, we could now choose
   to remove the check, since we can control what goes into the
   function.

## Running tests from the command line

   You’ve probably noticed by now that running tests in a
   popup terminal buffer is a pain. The spawned instance of
   Neovim inherits options from the parent instance, too, so
   this method can cause all kinds of headaches. The better
   option is to run tests from the command line. Add the
   following content to the Makefile we created earlier:

```
.PHONY: test
test:
        nvim --headless -u test/minimal.vim -c "lua require('plenary.test_harnes
s').test_directory_command('test')"
```

   This will start a headless instance of Neovim with the
   configuration specified in minimal.vim and tell it to
   run tests on files in the test directory. What goes into
   minimal.vim? Try this:

```
set rtp=$VIMRUNTIME
packadd plenary.nvim
packadd uppercase.nvim
```

   We reset rtp to prevent loading unwanted plugins and load the
   ones we need, which are Plenary and our plugin.

   You should now be able to run make test from the command line
   and see the same output:
   No more <C-\><C-n>. Please.

   You also have access to the exit code, which will instantly
   tell you if your tests succeeded. (If you want to get fancy,
   you could run your tests as part of a CI pipeline, too.)

   At this point, I recommend deleting the keymap we created   .
   earlier Running tests from the command line is always a     .
   better option                                               .

## Well done!

   I hope this article helps you avoid some of the headaches I
   faced when writing my first tests. The Plenary API is still
   unstable, but since I rely on it for my own plugins, I’ll
   continue to update this article if there are changes and add
   more tips as I find them.

