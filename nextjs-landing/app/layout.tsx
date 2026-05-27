import './globals.css'

export const metadata = {
  title: 'Lona - AI Workspace for Modern Teams',
  description: 'One inbox. One task list. One AI PM. Download Lona for macOS or use the web app.',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body style={{ margin: 0, padding: 0 }}>
        {children}
      </body>
    </html>
  )
}

