// Custom JavaScript for ECS Workshop

document.addEventListener('DOMContentLoaded', function() {
    
    // Initialize all custom functionality
    initImageLightbox();
    initCopyButtons();
    initProgressTracking();
    initSmoothScrolling();
    initImageLazyLoading();
    
});

// Image Lightbox functionality
function initImageLightbox() {
    const images = document.querySelectorAll('.workshop-image, .console-screenshot');
    
    images.forEach(img => {
        img.addEventListener('click', function() {
            openLightbox(this.src, this.alt);
        });
        
        // Add cursor pointer
        img.style.cursor = 'pointer';
    });
}

function openLightbox(src, alt) {
    // Create lightbox overlay
    const overlay = document.createElement('div');
    overlay.className = 'lightbox-overlay';
    overlay.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.9);
        display: flex;
        justify-content: center;
        align-items: center;
        z-index: 9999;
        cursor: pointer;
    `;
    
    // Create image element
    const img = document.createElement('img');
    img.src = src;
    img.alt = alt;
    img.style.cssText = `
        max-width: 90%;
        max-height: 90%;
        border-radius: 8px;
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
    `;
    
    // Create close button
    const closeBtn = document.createElement('button');
    closeBtn.innerHTML = '×';
    closeBtn.style.cssText = `
        position: absolute;
        top: 20px;
        right: 30px;
        background: #ff9900;
        color: white;
        border: none;
        font-size: 2rem;
        width: 50px;
        height: 50px;
        border-radius: 50%;
        cursor: pointer;
        z-index: 10000;
    `;
    
    overlay.appendChild(img);
    overlay.appendChild(closeBtn);
    document.body.appendChild(overlay);
    
    // Close lightbox events
    overlay.addEventListener('click', function(e) {
        if (e.target === overlay || e.target === closeBtn) {
            document.body.removeChild(overlay);
        }
    });
    
    // ESC key to close
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            if (document.body.contains(overlay)) {
                document.body.removeChild(overlay);
            }
        }
    });
}

// Copy to clipboard functionality
function initCopyButtons() {
    const codeBlocks = document.querySelectorAll('pre code');
    
    codeBlocks.forEach(block => {
        const pre = block.parentElement;
        
        // Create copy button
        const copyBtn = document.createElement('button');
        copyBtn.className = 'copy-button';
        copyBtn.innerHTML = '<i class="fas fa-copy"></i> Copy';
        
        // Position button
        pre.style.position = 'relative';
        pre.appendChild(copyBtn);
        
        // Copy functionality
        copyBtn.addEventListener('click', function() {
            const text = block.textContent;
            
            navigator.clipboard.writeText(text).then(function() {
                copyBtn.innerHTML = '<i class="fas fa-check"></i> Copied!';
                copyBtn.style.background = '#28a745';
                
                setTimeout(function() {
                    copyBtn.innerHTML = '<i class="fas fa-copy"></i> Copy';
                    copyBtn.style.background = '#ff9900';
                }, 2000);
            }).catch(function() {
                // Fallback for older browsers
                const textArea = document.createElement('textarea');
                textArea.value = text;
                document.body.appendChild(textArea);
                textArea.select();
                document.execCommand('copy');
                document.body.removeChild(textArea);
                
                copyBtn.innerHTML = '<i class="fas fa-check"></i> Copied!';
                setTimeout(function() {
                    copyBtn.innerHTML = '<i class="fas fa-copy"></i> Copy';
                }, 2000);
            });
        });
    });
}

// Progress tracking
function initProgressTracking() {
    const sections = document.querySelectorAll('h2, h3');
    const progressBar = document.querySelector('.progress-bar');
    
    if (!progressBar) return;
    
    let currentSection = 0;
    const totalSections = sections.length;
    
    // Update progress based on scroll
    window.addEventListener('scroll', function() {
        const scrollTop = window.pageYOffset;
        const windowHeight = window.innerHeight;
        const documentHeight = document.documentElement.scrollHeight;
        
        // Calculate progress percentage
        const progress = (scrollTop / (documentHeight - windowHeight)) * 100;
        progressBar.style.width = Math.min(progress, 100) + '%';
    });
}

// Smooth scrolling for anchor links
function initSmoothScrolling() {
    const links = document.querySelectorAll('a[href^="#"]');
    
    links.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href').substring(1);
            const targetElement = document.getElementById(targetId);
            
            if (targetElement) {
                targetElement.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
}

// Lazy loading for images
function initImageLazyLoading() {
    const images = document.querySelectorAll('img[data-src]');
    
    const imageObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const img = entry.target;
                img.src = img.dataset.src;
                img.classList.remove('lazy');
                imageObserver.unobserve(img);
            }
        });
    });
    
    images.forEach(img => imageObserver.observe(img));
}

// Add loading animation to images
function addImageLoadingAnimation() {
    const images = document.querySelectorAll('.workshop-image, .console-screenshot');
    
    images.forEach(img => {
        img.addEventListener('load', function() {
            this.style.opacity = '1';
        });
        
        img.addEventListener('error', function() {
            this.style.opacity = '0.5';
            this.title = 'Image failed to load';
        });
        
        // Initial state
        img.style.opacity = '0';
        img.style.transition = 'opacity 0.3s ease';
    });
}

// Search functionality enhancement
function enhanceSearch() {
    const searchInput = document.querySelector('#search-by');
    
    if (searchInput) {
        searchInput.addEventListener('input', function() {
            const query = this.value.toLowerCase();
            const content = document.querySelector('#body');
            
            if (query.length > 2) {
                highlightSearchTerms(content, query);
            } else {
                removeHighlights(content);
            }
        });
    }
}

function highlightSearchTerms(element, query) {
    // Simple search highlighting
    const walker = document.createTreeWalker(
        element,
        NodeFilter.SHOW_TEXT,
        null,
        false
    );
    
    const textNodes = [];
    let node;
    
    while (node = walker.nextNode()) {
        textNodes.push(node);
    }
    
    textNodes.forEach(textNode => {
        const text = textNode.textContent;
        const regex = new RegExp(`(${query})`, 'gi');
        
        if (regex.test(text)) {
            const highlightedText = text.replace(regex, '<mark>$1</mark>');
            const span = document.createElement('span');
            span.innerHTML = highlightedText;
            textNode.parentNode.replaceChild(span, textNode);
        }
    });
}

function removeHighlights(element) {
    const marks = element.querySelectorAll('mark');
    marks.forEach(mark => {
        mark.outerHTML = mark.innerHTML;
    });
}

// Add workshop-specific functionality
function addWorkshopFeatures() {
    // Add step numbers to headings
    const stepHeadings = document.querySelectorAll('h3');
    stepHeadings.forEach((heading, index) => {
        if (heading.textContent.includes('Bước')) {
            const stepNumber = document.createElement('span');
            stepNumber.className = 'step-indicator';
            stepNumber.textContent = index + 1;
            heading.insertBefore(stepNumber, heading.firstChild);
        }
    });
    
    // Add AWS service icons
    addServiceIcons();
    
    // Add cost calculator
    addCostCalculator();
}

function addServiceIcons() {
    const serviceMap = {
        'ECS': 'fas fa-cube',
        'VPC': 'fas fa-network-wired',
        'ALB': 'fas fa-balance-scale',
        'CloudWatch': 'fas fa-chart-line',
        'IAM': 'fas fa-user-shield',
        'Route 53': 'fas fa-globe'
    };
    
    Object.keys(serviceMap).forEach(service => {
        const elements = document.querySelectorAll(`*:contains("${service}")`);
        elements.forEach(el => {
            if (el.children.length === 0) { // Only text nodes
                const icon = document.createElement('i');
                icon.className = serviceMap[service];
                icon.style.marginRight = '0.5rem';
                el.insertBefore(icon, el.firstChild);
            }
        });
    });
}

function addCostCalculator() {
    // Simple cost calculator for workshop resources
    const costData = {
        'ECS Fargate': { hourly: 0.75, duration: 4 },
        'ALB': { hourly: 0.025, duration: 4 },
        'NAT Gateway': { hourly: 0.045, duration: 4 },
        'VPC Flow Logs': { hourly: 0.02, duration: 4 }
    };
    
    let totalCost = 0;
    Object.values(costData).forEach(service => {
        totalCost += service.hourly * service.duration;
    });
    
    // Add cost info to relevant sections
    const costInfo = document.createElement('div');
    costInfo.className = 'alert alert-info';
    costInfo.innerHTML = `
        <i class="fas fa-calculator"></i>
        <strong>Estimated Workshop Cost:</strong> $${totalCost.toFixed(2)}
        <br><small>Based on 4-hour workshop duration</small>
    `;
    
    const firstSection = document.querySelector('#body h2');
    if (firstSection) {
        firstSection.parentNode.insertBefore(costInfo, firstSection.nextSibling);
    }
}

// Initialize workshop features when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    addWorkshopFeatures();
    addImageLoadingAnimation();
    enhanceSearch();
});

// Add CSS for dynamic elements
const style = document.createElement('style');
style.textContent = `
    .lazy {
        opacity: 0;
        transition: opacity 0.3s;
    }
    
    mark {
        background: #ff9900;
        color: white;
        padding: 0.1em 0.2em;
        border-radius: 2px;
    }
    
    .step-indicator {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 2rem;
        height: 2rem;
        background: #ff9900;
        color: white;
        border-radius: 50%;
        font-weight: bold;
        margin-right: 0.5rem;
        font-size: 0.9rem;
    }
`;
document.head.appendChild(style);
