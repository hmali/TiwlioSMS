// Main JavaScript for Twilio Bulk SMS Application

document.addEventListener('DOMContentLoaded', function() {
    // Initialize Bootstrap tooltips
    var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });
    
    // Auto-hide alerts after 5 seconds
    const alerts = document.querySelectorAll('.alert-dismissible');
    alerts.forEach(function(alert) {
        setTimeout(function() {
            const bsAlert = new bootstrap.Alert(alert);
            bsAlert.close();
        }, 5000);
    });
    
    // Phone number validation
    function validatePhoneNumber(phone) {
        const phoneRegex = /^\+?1?[2-9]\d{2}[2-9]\d{2}\d{4}$/;
        return phoneRegex.test(phone.replace(/[\s\-\(\)]/g, ''));
    }
    
    // File upload validation
    const fileInput = document.getElementById('phone_file');
    if (fileInput) {
        fileInput.addEventListener('change', function() {
            const file = this.files[0];
            if (file) {
                const validTypes = ['text/plain', 'text/csv', 'application/vnd.ms-excel'];
                const validExtensions = ['.txt', '.csv'];
                const fileName = file.name.toLowerCase();
                
                let isValid = validTypes.includes(file.type) || 
                             validExtensions.some(ext => fileName.endsWith(ext));
                
                if (!isValid) {
                    this.setCustomValidity('Please upload a .txt or .csv file');
                    this.classList.add('is-invalid');
                } else if (file.size > 16 * 1024 * 1024) { // 16MB
                    this.setCustomValidity('File size must be less than 16MB');
                    this.classList.add('is-invalid');
                } else {
                    this.setCustomValidity('');
                    this.classList.remove('is-invalid');
                    this.classList.add('is-valid');
                }
            }
        });
    }
    
    // Character count and SMS count for message textarea
    const messageTextarea = document.getElementById('message_body');
    if (messageTextarea) {
        messageTextarea.addEventListener('input', function() {
            updateMessageStats(this.value);
        });
        
        // Initialize on page load
        updateMessageStats(messageTextarea.value);
    }
    
    function updateMessageStats(text) {
        const charCount = text.length;
        const smsCount = calculateSMSCount(charCount);
        
        const charCountEl = document.getElementById('char_count');
        const smsCountEl = document.getElementById('sms_count');
        
        if (charCountEl) charCountEl.textContent = charCount;
        if (smsCountEl) smsCountEl.textContent = smsCount + ' SMS';
        
        // Update styling based on length
        const messageEl = document.getElementById('message_body');
        if (messageEl) {
            messageEl.classList.remove('is-valid', 'is-invalid');
            if (charCount > 1600) {
                messageEl.classList.add('is-invalid');
            } else if (charCount > 0) {
                messageEl.classList.add('is-valid');
            }
        }
    }
    
    function calculateSMSCount(length) {
        if (length === 0) return 1;
        if (length <= 160) return 1;
        return Math.ceil(length / 153); // 153 chars for multi-part SMS
    }
    
    // Form submission handling
    const smsForm = document.getElementById('smsForm');
    if (smsForm) {
        smsForm.addEventListener('submit', function(e) {
            const submitBtn = document.getElementById('sendBtn');
            const confirmCheck = document.getElementById('confirm_send');
            
            if (!confirmCheck.checked) {
                e.preventDefault();
                alert('Please confirm that you want to send this campaign');
                return;
            }
            
            // Show loading state
            if (submitBtn) {
                submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Processing...';
                submitBtn.disabled = true;
            }
        });
    }
    
    // Real-time campaign status updates
    function setupStatusUpdates() {
        const statusContainer = document.getElementById('campaign-status');
        if (!statusContainer) return;
        
        const campaignId = window.location.pathname.split('/').pop();
        if (!campaignId || isNaN(campaignId)) return;
        
        updateCampaignStatus(campaignId);
    }
    
    function updateCampaignStatus(campaignId) {
        fetch(`/api/campaign/${campaignId}/status`)
            .then(response => response.json())
            .then(data => {
                if (data.error) return;
                
                updateStatusDisplay(data);
                
                // Continue polling if still sending
                if (data.status === 'sending' || data.status === 'pending') {
                    setTimeout(() => updateCampaignStatus(campaignId), 3000);
                }
            })
            .catch(error => {
                console.error('Error updating campaign status:', error);
            });
    }
    
    function updateStatusDisplay(data) {
        // Update counts
        const successCountEl = document.getElementById('success-count');
        const failedCountEl = document.getElementById('failed-count');
        
        if (successCountEl) successCountEl.textContent = data.successful;
        if (failedCountEl) failedCountEl.textContent = data.failed;
        
        // Update progress bars
        if (data.total > 0) {
            const successPercentage = (data.successful / data.total) * 100;
            const failedPercentage = (data.failed / data.total) * 100;
            
            const successProgress = document.getElementById('success-progress');
            const failedProgress = document.getElementById('failed-progress');
            
            if (successProgress) {
                successProgress.style.width = successPercentage + '%';
                successProgress.textContent = data.successful + ' sent';
            }
            
            if (failedProgress) {
                failedProgress.style.width = failedPercentage + '%';
                failedProgress.textContent = data.failed + ' failed';
            }
        }
        
        // Update status badge
        const statusEl = document.getElementById('campaign-status');
        if (statusEl && data.status) {
            let badgeClass = 'bg-info';
            let statusText = 'Pending';
            
            switch(data.status) {
                case 'completed':
                    badgeClass = 'bg-success';
                    statusText = 'Completed';
                    break;
                case 'sending':
                    badgeClass = 'bg-warning';
                    statusText = 'Sending';
                    break;
                case 'error':
                    badgeClass = 'bg-danger';
                    statusText = 'Error';
                    break;
            }
            
            statusEl.innerHTML = `<span class="badge ${badgeClass}">${statusText}</span>`;
        }
        
        // Reload page when completed to show all messages
        if (data.status === 'completed') {
            setTimeout(() => {
                window.location.reload();
            }, 2000);
        }
    }
    
    // Initialize status updates if on campaign page
    if (window.location.pathname.includes('/campaign/')) {
        setupStatusUpdates();
    }
    
    // Copy to clipboard functionality
    function setupCopyButtons() {
        const copyButtons = document.querySelectorAll('[data-copy]');
        copyButtons.forEach(button => {
            button.addEventListener('click', function() {
                const text = this.getAttribute('data-copy');
                navigator.clipboard.writeText(text).then(() => {
                    // Show success feedback
                    const originalText = this.textContent;
                    this.textContent = 'Copied!';
                    this.classList.add('btn-success');
                    
                    setTimeout(() => {
                        this.textContent = originalText;
                        this.classList.remove('btn-success');
                    }, 2000);
                }).catch(err => {
                    console.error('Failed to copy text: ', err);
                });
            });
        });
    }
    
    // Initialize copy buttons
    setupCopyButtons();
    
    // Confirm before leaving page with unsaved changes
    let hasUnsavedChanges = false;
    
    const formInputs = document.querySelectorAll('input, textarea, select');
    formInputs.forEach(input => {
        input.addEventListener('change', () => {
            hasUnsavedChanges = true;
        });
    });
    
    window.addEventListener('beforeunload', (e) => {
        if (hasUnsavedChanges && !document.querySelector('form').submitted) {
            e.preventDefault();
            e.returnValue = '';
        }
    });
    
    // Clear unsaved changes flag on form submission
    const forms = document.querySelectorAll('form');
    forms.forEach(form => {
        form.addEventListener('submit', () => {
            form.submitted = true;
            hasUnsavedChanges = false;
        });
    });
});

// Utility functions
function formatPhoneNumber(phone) {
    // Remove all non-digits
    const cleaned = phone.replace(/\D/g, '');
    
    // Add country code if missing
    if (cleaned.length === 10) {
        return '+1' + cleaned;
    } else if (cleaned.length === 11 && cleaned[0] === '1') {
        return '+' + cleaned;
    }
    
    return phone; // Return original if can't format
}

function showToast(message, type = 'info') {
    // Create toast element
    const toastContainer = document.getElementById('toast-container') || 
                          createToastContainer();
    
    const toast = document.createElement('div');
    toast.className = `toast align-items-center text-white bg-${type} border-0`;
    toast.setAttribute('role', 'alert');
    toast.innerHTML = `
        <div class="d-flex">
            <div class="toast-body">${message}</div>
            <button type="button" class="btn-close btn-close-white me-2 m-auto" 
                    data-bs-dismiss="toast"></button>
        </div>
    `;
    
    toastContainer.appendChild(toast);
    
    const bsToast = new bootstrap.Toast(toast);
    bsToast.show();
    
    // Remove toast element after it's hidden
    toast.addEventListener('hidden.bs.toast', () => {
        toast.remove();
    });
}

function createToastContainer() {
    const container = document.createElement('div');
    container.id = 'toast-container';
    container.className = 'toast-container position-fixed bottom-0 end-0 p-3';
    container.style.zIndex = '9999';
    document.body.appendChild(container);
    return container;
}
