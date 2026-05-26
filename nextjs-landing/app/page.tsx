import styles from './page.module.css'
import Image from 'next/image'

export default function Home() {
  return (
    <div className={styles.wrapper}>
      {/* Navigation */}
      <nav className={styles.nav}>
        <div className={styles.navContainer}>
          <div className={styles.logo}>Lona</div>
          <div className={styles.navLinks}>
            <a href="#features">Features</a>
            <a href="#how-it-works">How It Works</a>
            <a href="#pricing">For SMBs</a>
            <a href="#faq">FAQ</a>
          </div>
          <div className={styles.ctaButtons}>
            <a href="/app" className={styles.primaryButton}>Get Started</a>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className={styles.hero}>
        <div className={styles.heroContainer}>
          <div className={styles.heroContent}>
            <h1 className={styles.heroTitle}>
              Work Across All Tools From One AI Workspace
            </h1>
            <p className={styles.heroSubtitle}>
              One inbox. One task list.<br />One AI PM.
            </p>
            <div className={styles.heroCTAs}>
              <a href="/app" className={styles.ctaButton}>Try For Free</a>
              <a href="#download" className={`${styles.ctaButton} ${styles.secondary}`}>Watch Demo</a>
            </div>
          </div>
          <div className={styles.heroImage}>
            <Image 
              src="/app/assets/assets/images/ChatGPT Image Nov 7, 2025, 05_52_27 PM.png" 
              alt="Lona Workspace" 
              width={600} 
              height={600}
              className={styles.heroImageContent}
            />
          </div>
        </div>
      </section>

      {/* Key Features */}
      <section id="features" className={`${styles.section} ${styles.featuresSection}`}>
        <div className={styles.container}>
          <h2 className={styles.sectionTitle}>Key Features</h2>
          <div className={styles.featuresGrid}>
            <div className={styles.featureCard}>
              <div className={styles.iconBubble} data-icon="inbox">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M4 4H20C21.1 4 22 4.9 22 6V18C22 19.1 21.1 20 20 20H4C2.9 20 2 19.1 2 18V6C2 4.9 2.9 4 4 4Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M22 6L12 13L2 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              <h3 className={styles.featureCardTitle}>Unified Inbox</h3>
              <p className={styles.featureCardText}>
                See and reply to Slack, Gmail, and Teams in one feed. No switching.
              </p>
            </div>
            <div className={styles.featureCard}>
              <div className={styles.iconBubble} data-icon="pm">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M12 2L2 7L12 12L22 7L12 2Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M2 17L12 22L22 17" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M2 12L12 17L22 12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              <h3 className={styles.featureCardTitle}>AI Personal PM</h3>
              <p className={styles.featureCardText}>
                Detects tasks, prioritizes to-dos, and keeps your schedule on track automatically.
              </p>
            </div>
            <div className={styles.featureCard}>
              <div className={styles.iconBubble} data-icon="workspace">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M3 9L12 2L21 9V20C21 20.5304 20.7893 21.0391 20.4142 21.4142C20.0391 21.7893 19.5304 22 19 22H5C4.46957 22 3.96086 21.7893 3.58579 21.4142C3.21071 21.0391 3 20.5304 3 20V9Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M9 22V12H15V22" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              <h3 className={styles.featureCardTitle}>Smart Workspace</h3>
              <p className={styles.featureCardText}>
                Team, projects, and communication in one place. Mac, iOS, and Web.
              </p>
            </div>
          </div>
        </div>
      </section>

      <hr className={styles.sectionDivider} aria-hidden="true" />

      {/* Why Lona */}
      <section className={`${styles.section} ${styles.whySection}`}>
        <div className={styles.container}>
          <div className={styles.whyContent}>
            <h2 className={styles.sectionTitle}>The Only Tool That Replaces<br />Switching Apps</h2>
            <div className={styles.whyList}>
              <div className={styles.whyItem}>
                <span className={styles.checkmark}>✓</span>
                <span>See everything in one place</span>
              </div>
              <div className={styles.whyItem}>
                <span className={styles.checkmark}>✓</span>
                <span>Never lose track of messages or tasks</span>
              </div>
              <div className={styles.whyItem}>
                <span className={styles.checkmark}>✓</span>
                <span>Focus on what matters — not chasing notifications</span>
              </div>
            </div>
            <p className={styles.tagline}>Focus on the work. Not on where the work lives.</p>
          </div>
        </div>
      </section>

      <hr className={styles.sectionDivider} aria-hidden="true" />

      {/* Download CTA */}
      <section id="download" className={`${styles.section} ${styles.downloadSection}`}>
        <div className={styles.container}>
          <div className={styles.downloadCard}>
            <h2 className={styles.downloadTitle}>Try Lona Today</h2>
            <p className={styles.downloadSubtitle}>One Workspace. One Inbox. One AI Brain.</p>
            <div className={styles.downloadButtons}>
              <a href="#download" className={styles.downloadButton}>
                <svg className={styles.downloadButtonIcon} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M12 2L2 7L12 12L22 7L12 2Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M2 17L12 22L22 17" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M2 12L12 17L22 12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
                Download for Mac
              </a>
              <a href="#download" className={styles.downloadButton}>
                <svg className={styles.downloadButtonIcon} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M18 2H6C4.9 2 4 2.9 4 4V20C4 21.1 4.9 22 6 22H18C19.1 22 20 21.1 20 20V4C20 2.9 19.1 2 18 2Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M12 18C13.1 18 14 17.1 14 16C14 14.9 13.1 14 12 14C10.9 14 10 14.9 10 16C10 17.1 10.9 18 12 18Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
                Get iOS App
              </a>
              <a href="/app" className={styles.downloadButton}>
                <svg className={styles.downloadButtonIcon} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M21 16V8C21 7.46957 20.7893 6.96086 20.4142 6.58579C20.0391 6.21071 19.5304 6 19 6H5C4.46957 6 3.96086 6.21071 3.58579 6.58579C3.21071 6.96086 3 7.46957 3 8V16C3 16.5304 3.21071 17.0391 3.58579 17.4142C3.96086 17.7893 4.46957 18 5 18H19C19.5304 18 20.0391 17.7893 20.4142 17.4142C20.7893 17.0391 21 16.5304 21 16Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M7 10H17M7 14H13" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
                Open Web App
              </a>
            </div>
            <p className={styles.downloadTagline}>Free to start. Built for modern teams.</p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className={styles.footer}>
        <div className={styles.footerContainer}>
          <div className={styles.footerContent}>
            <div className={styles.footerBrand}>
              <div className={styles.footerLogo}>Lona</div>
              <p className={styles.footerDescription}>
                All-in-one AI workspace for SMBs. Privacy-first, built for modern teams.
              </p>
            </div>
            <div className={styles.footerLinks}>
              <div className={styles.footerLinksTitle}>Quick Links</div>
              <a href="#support">Support</a>
              <a href="#docs">Documentation</a>
              <a href="/terms">Terms of Use</a>
              <a href="/privacy">Privacy Policy</a>
            </div>
          </div>
          <div className={styles.footerBottom}>
            <p className={styles.footerTagline}>
              Privacy-first | Built with ❤️ in the USA
            </p>
            <div className={styles.footerSocial}>
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
          <p className={styles.footerCopyright}>© 2025 Lona. All rights reserved.</p>
        </div>
      </footer>
    </div>
  )
}
