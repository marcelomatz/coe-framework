# coe_mail

Email app for the smartphone and tablet. Installed on every device (`coe_apps`, System category).

## Accounts

- Any character can create accounts on the public `PublicDomain` domain (`name@correio.coe`). The limit is `Accounts.MaxPerCharacter` (3) accounts per character.
- The name before @ must be 3 to 24 characters: lowercase letters, numbers, `.`, `_`, or `-`. It cannot start or end with a symbol or contain two symbols in a row. Names in `Reserved` are blocked.
- The password must be 6 to 32 characters and is stored as a hash (`GetPasswordHash`).
- Anyone who knows the password can sign in to the account on any device.
- **My accounts** lists accounts created by the character. From there, you can:
  - **Reset password** ("forgot password"): signs the account out of other devices and opens it on this one.
  - **Delete** the account (password required): deletes the messages and frees the address.
- **Settings**:
  - display name and signature (appended to new messages);
  - change password (current password required and signs out the account on other devices);
  - **Sign out** on this device.
- After `Login.MaxFailures` consecutive incorrect passwords, the account is locked for `Login.LockSeconds`.

## Sessions per device

- The session is tied to the device, not the character:
  - **Smartphone**: by serial number (`coe_phone:ActiveDevice`). Anyone who picks up the unlocked phone can see the accounts open on it.
  - **Tablet**: by character.
- Each device can open up to `Login.MaxSessionsPerDevice` accounts and switch between them using the selector at the top. **Add account** signs into another.

## Messages

- **Folders**:
  - Inbox, Starred, Sent, Drafts, Archive, and Trash.
  - Trash is automatically deleted after `Messages.TrashDays` days; the **Empty** button asks for confirmation.
- **Compose**:
  - To, Cc, and Bcc fields: up to `MaxRecipients` addresses in total, separated by commas;
  - subject and text have size limits;
  - there is a `SendCooldownSeconds` wait between sends from the same account.
- **Addresses**: an address that does not exist rejects the entire send and identifies it. An account at capacity (`MaxPerAccount` messages) cannot receive; the sender is notified.
- **Bcc**: only the sender sees the blind-copy list.
- **Reading**: reply, reply all (without repeating your own address), forward, star, mark unread, archive or unarchive, move to Trash, restore, and permanently delete.
- **Drafts**:
  - **Save draft** stores the text; leaving the editor with changes also saves it;
  - opening a draft returns to the editor;
  - sending removes the message from Drafts.
- **Search** in the subject, text, sender, and recipients of the open folder.
- **New mail notification**: a new email notifies (`coe_notify`) anyone with a device connected to the account. When the app is open, the inbox refreshes every 20 seconds.

## For other resources

`Send(from, to, subject, body)` sends system emails. Only resources in `SystemCallers` can use it.

| Parameter | Format |
|---|---|
| `from` | `{ address, name }` |
| `to` | address or list |
| return | `{ ok, bounced }` or `{ ok = false, error }` |

## Database

| Table | Contents |
|---|---|
| `coe_mail_accounts` | address, domain, name, signature, password hash, and creating character |
| `coe_mail_sessions` | accounts open on a device (`phone:<serial>` or `tablet:<character>`) |
| `coe_mail_messages` | content: sender, subject, text, and To/Cc/Bcc lists |
| `coe_mail_boxes` | one row per account that sees the message: folder, read status, star, and role (`from`/`to`) |

The `domain` column already separates the public domain from custom domains. Custom domains will come later with the email provider and carrier domain registration (`coe_telecom`). Periodic cleanup (`PurgeMinutes`) deletes expired Trash and messages no longer used by any mailbox.

## Dependencies

`coe_core`, `coe_database`, `coe_logging`, `coe_apps` (installation), `coe_phone`/`coe_tablet` (devices), and `coe_notify` (notifications). The resource must be in the allowlists for `coe_database`, `coe_notify`, `coe_logging`, and `coe_audit`.
