import { Head } from '@inertiajs/react';

export default function Home() {
  return (
    <>
      <Head title="Welcome" />
      <main className="min-h-screen flex items-center justify-center p-8">
        <div className="max-w-xl text-center space-y-4">
          <h1 className="text-4xl font-bold tracking-tight">Welcome to WebTemplate</h1>
          <p className="text-base text-gray-600 dark:text-gray-400">Phoenix 1.8 · Inertia.js · React · SSR</p>
        </div>
      </main>
    </>
  );
}
