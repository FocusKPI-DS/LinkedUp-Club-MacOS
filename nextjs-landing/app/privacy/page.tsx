import styles from './page.module.css'
import navStyles from '../page.module.css'
import Link from 'next/link'

export default function PrivacyPage() {
  return (
    <div className={navStyles.wrapper}>
      {/* Navigation */}
      <nav className={navStyles.nav}>
        <div className={navStyles.navContainer}>
          <Link href="/" className={navStyles.logo}>Lona</Link>
          <div className={navStyles.navLinks}>
            <a href="/#features">Features</a>
            <a href="/#how-it-works">How It Works</a>
            <a href="/#pricing">For SMBs</a>
            <a href="/#faq">FAQ</a>
          </div>
          <div className={navStyles.ctaButtons}>
            <a href="/#download" className={navStyles.primaryButton}>Get Started</a>
          </div>
        </div>
      </nav>

      <div className={styles.container}>
        <div className={styles.content}>
        <h1 className={styles.title}>Privacy Policy</h1>
        <p className={styles.lastUpdated}>Last Updated: November 7, 2025</p>

        <div className={styles.intro}>
          <p>
            This Privacy Policy explains how Lona Club ("Lona," "we," "our," or "us") collects, uses, and protects your information when you use our platform.
          </p>
        </div>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>1. Information We Collect</h2>
          
          <h3 className={styles.subsectionTitle}>a. Information You Provide</h3>
          <ul className={styles.list}>
            <li>Account details (name, email, password)</li>
            <li>Workspace and organization info</li>
            <li>Messages or data you share through integrations</li>
          </ul>

          <h3 className={styles.subsectionTitle}>b. Information from Integrations</h3>
          <p>
            When you connect third-party tools (e.g., Slack, Gmail, Calendar, Teams), we may securely access metadata (such as message headers, timestamps, and event summaries) to display unified information.
          </p>
          <p>
            We never store or read message content unless required for app functionality.
          </p>

          <h3 className={styles.subsectionTitle}>c. Usage Data</h3>
          <p>
            We collect analytics (e.g., clicks, features used, device type) to improve performance and reliability.
          </p>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>2. How We Use Your Information</h2>
          <p>We use your data to:</p>
          <ul className={styles.list}>
            <li>Provide and improve Lona's features</li>
            <li>Sync and display data from integrated services</li>
            <li>Offer customer support and updates</li>
            <li>Enhance personalization and AI task prioritization</li>
            <li>Ensure platform security and prevent abuse</li>
          </ul>
          <p>
            We do not sell personal data.
          </p>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>3. Data Retention</h2>
          <p>
            We retain data only as long as necessary to deliver our Service or as required by law.
          </p>
          <p>
            You can delete your account at any time, and your data will be permanently erased from our systems within 30 days.
          </p>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>4. Data Sharing</h2>
          <p>We may share limited data with:</p>
          <ul className={styles.list}>
            <li>Service providers (e.g., hosting, analytics, payment processors) who are bound by confidentiality agreements</li>
            <li>Legal authorities, if required by law or to prevent harm</li>
          </ul>
          <p>
            We never share your data for advertising purposes.
          </p>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>5. Data Security</h2>
          <p>
            We use encryption (HTTPS, AES-256) and follow industry best practices for secure storage and transmission.
          </p>
          <p>
            However, no system is fully secure, and you use the Service at your own risk.
          </p>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>6. International Data Transfers</h2>
          <p>
            If you are outside the U.S., your data may be processed in the United States or other countries that may have different data-protection laws. We maintain appropriate safeguards to protect your information.
          </p>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>7. Your Rights</h2>
          <p>
            Depending on your region (e.g., GDPR, CCPA), you may have rights to:
          </p>
          <ul className={styles.list}>
            <li>Access, correct, or delete your data</li>
            <li>Object to or restrict processing</li>
            <li>Export your data</li>
          </ul>
          <p>
            You can exercise these rights by contacting <a href="mailto:lona_support@focuskpi.com">lona_support@focuskpi.com</a>.
          </p>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>8. Cookies and Tracking</h2>
          <p>
            We use cookies and analytics tools (like Google Analytics) to understand usage and improve UX.
          </p>
          <p>
            You can manage or disable cookies in your browser settings.
          </p>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>9. Changes to This Policy</h2>
          <ul className={styles.list}>
            <li>We may update this Privacy Policy periodically.</li>
            <li>We will notify you via email or in-app notice if changes are significant.</li>
          </ul>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>10. Contact</h2>
          <p>For privacy inquiries:</p>
          <p className={styles.contact}>
            📧 <a href="mailto:lona_support@focuskpi.com">lona_support@focuskpi.com</a>
          </p>
        </section>
        </div>
      </div>

      {/* Footer */}
      <footer className={navStyles.footer}>
        <div className={navStyles.footerContainer}>
          <div className={navStyles.footerContent}>
            <div className={navStyles.footerBrand}>
              <div className={navStyles.footerLogo}>Lona</div>
              <p className={navStyles.footerDescription}>
                All-in-one AI workspace for SMBs. Privacy-first, built for modern teams.
              </p>
            </div>
            <div className={navStyles.footerLinks}>
              <div className={navStyles.footerLinksTitle}>Quick Links</div>
              <a href="/#support">Support</a>
              <a href="/#docs">Documentation</a>
              <a href="/terms">Terms of Use</a>
              <a href="/privacy">Privacy Policy</a>
            </div>
          </div>
          <div className={navStyles.footerBottom}>
            <p className={navStyles.footerTagline}>
              Privacy-first | Built with ❤️ in the USA
            </p>
            <div className={navStyles.footerSocial}>
              <a href="#twitter" aria-label="Twitter">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M23 3C22.0424 3.67548 20.9821 4.19211 19.88 4.53C19.2942 3.83751 18.5307 3.34669 17.689 3.12393C16.8472 2.90116 15.9561 2.95791 15.19 3.29C13.84 3.83 12.89 5.16 12.89 6.78V7.53C9.3 7.58 6.14 5.88 4 3C4 3 -0.91 13.17 8.71 17.61C6.62 19.31 4.26 20.27 2 20C11.24 25.34 22.5 20 22.5 9.5C22.4996 9.22146 22.4769 8.94359 22.43 8.67C23.4257 7.92521 24.23 6.99833 24.79 5.95L23 3Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </a>
              <a href="#linkedin" aria-label="LinkedIn">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M16 8C17.5913 8 19.1174 8.63214 20.2426 9.75736C21.3679 10.8826 22 12.4087 22 14V21H18V14C18 13.4696 17.7893 12.9609 17.4142 12.5858C17.0391 12.2107 16.5304 12 16 12C15.4696 12 14.9609 12.2107 14.5858 12.5858C14.2107 12.9609 14 13.4696 14 14V21H10V14C10 12.4087 10.6321 10.8826 11.7574 9.75736C12.8826 8.63214 14.4087 8 16 8Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M6 9H2V21H6V9Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M4 6C5.10457 6 6 5.10457 6 4C6 2.89543 5.10457 2 4 2C2.89543 2 2 2.89543 2 4C2 5.10457 2.89543 6 4 6Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </a>
              <a href="#github" aria-label="GitHub">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M9 19C4 20.5 4 16.5 2 16M22 16V20C22 20.5304 21.7893 21.0391 21.4142 21.4142C21.0391 21.7893 20.5304 22 20 22H16C15.4696 22 14.9609 21.7893 14.5858 21.4142C14.2107 21.0391 14 20.5304 14 20V16C14 15.4696 14.2107 14.9609 14.5858 14.5858C14.9609 14.2107 15.4696 14 16 14H20C20.5304 14 21.0391 14.2107 21.4142 14.5858C21.7893 14.9609 22 15.4696 22 16Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </a>
            </div>
          </div>
          <p className={navStyles.footerCopyright}>© 2025 Lona. All rights reserved.</p>
        </div>
      </footer>
    </div>
  )
}

