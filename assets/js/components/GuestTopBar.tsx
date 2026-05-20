import LocaleSelector from './LocaleSelector';
import ThemeToggle from './ThemeToggle';

/**
 * Borderless top bar for the public/guest pages (Home + the auth
 * screens). Pins the theme + locale toggles to the top-right of the
 * viewport. Shared by both pages so the toggles stay put when
 * navigating between them — without this they jumped around.
 */
export default function GuestTopBar() {
  return (
    <header className="flex items-center justify-end gap-3 px-4 py-3 sm:px-6">
      <ThemeToggle />
      <LocaleSelector />
    </header>
  );
}
