vim.g.mapleader = " "
vim.keymap.set("n", "<leader>cd", vim.cmd.Ex)
vim.keymap.set("n", "<C-n>", ":Neotree toggle<CR>")

-- Cycle focus to next window
vim.keymap.set("n", "<leader>w", "<C-w>w")

-- Or specifically navigate left/right
vim.keymap.set("n", "<C-h>", "<C-w>h")  -- Move focus left
vim.keymap.set("n", "<C-l>", "<C-w>l")  -- Move focus right

-- Move lines in Normal Mode
vim.keymap.set('n', '<A-Down>', ':m .+1<CR>==', { desc = 'Move line down' })
vim.keymap.set('v', '<A-Up>', ':m .-2<CR>==', { desc = 'Move line up' })

-- Move lines in Visual Mode
vim.keymap.set('v', '<A-Down>', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
vim.keymap.set('v', '<A-Up>', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })
