# 🔧 GitHub Pages Troubleshooting Guide

## ❌ Các vấn đề thường gặp và cách khắc phục

### 1. **Images không load trên GitHub Pages**

#### Nguyên nhân:
- File tên có ký tự đặc biệt hoặc double extension
- Path không đúng trong markdown
- File size quá lớn (>25MB per file, >100MB per repo)

#### ✅ Giải pháp:
```bash
# Kiểm tra file có tên lỗi
find . -name "*.png.png" -o -name "*.jpg.jpg" -o -name "*.jpeg.jpeg"

# Kiểm tra file size lớn (>5MB)
find . -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" | xargs ls -lh | awk '$5 > "5M"'

# Rename file nếu cần
mv "problematic-file-name.png" "clean-file-name.png"
```

### 2. **Hugo shortcodes không hoạt động**

#### Nguyên nhân:
- GitHub Pages đang dùng Jekyll thay vì Hugo
- Workflow không được cấu hình đúng

#### ✅ Giải pháp:
```bash
# Tạo file .nojekyll (đã có)
echo "" > .nojekyll

# Kiểm tra GitHub Pages Settings:
# Repository → Settings → Pages → Source = "GitHub Actions"
```

### 3. **Build fails với Hugo**

#### Nguyên nhân:
- Date format không đúng
- Missing dependencies
- Syntax errors trong content

#### ✅ Giải pháp:
```bash
# Test build locally
hugo --gc --minify

# Fix date format trong frontmatter
# Từ: date : "`r Sys.Date()`"
# Thành: date : "2024-08-13"
```

## 🔍 Diagnostic Commands

### Kiểm tra repository health:
```bash
# Check repo size
du -sh .

# Check large files
find . -size +1M -type f -exec ls -lh {} \;

# Check problematic filenames
find . -name "*[[:space:]]*" -o -name "*[()]*" -o -name "*[&]*"

# Test Hugo build
hugo --gc --minify --verbose
```

### Kiểm tra Git status:
```bash
# Check current status
git status

# Check recent commits
git log --oneline -5

# Check remote
git remote -v
```

## 📊 Current Status

### ✅ Repository Health Check:
- [x] Repository size: 66MB (acceptable)
- [x] No problematic filenames found
- [x] Hugo build successful locally
- [x] All images organized properly
- [x] .nojekyll file present
- [x] GitHub Actions workflow configured

### ✅ Files Structure:
```
static/images/
├── 3-cluster-setup/
│   ├── 01-vpc/
│   ├── 02-subnets/
│   ├── 03-igw/
│   ├── 04-nat/
│   ├── 05-routes/
│   └── 06-security/
├── 4-service-discovery/
├── 5-load-balancing/
├── 6-security/
├── 7-monitoring/
└── 8-cleanup/
```

## 🎯 Next Steps

### 1. Verify GitHub Pages Settings
```
1. Go to: https://github.com/Binh2423/ECS_Advanced_Networking/settings/pages
2. Ensure Source = "GitHub Actions" (NOT "Deploy from branch")
3. Wait for workflow to complete
```

### 2. Monitor Deployment
```
1. Go to: https://github.com/Binh2423/ECS_Advanced_Networking/actions
2. Check "Deploy Hugo site to Pages" workflow
3. Review logs if there are errors
```

### 3. Test Website
```
1. Visit: https://binh2423.github.io/ECS_Advanced_Networking/
2. Check if all images load correctly
3. Verify Hugo shortcodes work (alerts, buttons, etc.)
```

## 🚨 Emergency Fixes

### If images still don't load:

1. **Check image paths in markdown:**
```markdown
# Correct format:
![Description](/images/folder/image.png)

# NOT:
![Description](../static/images/folder/image.png)
```

2. **Optimize large images:**
```bash
# Install imagemagick
sudo apt-get install imagemagick

# Resize large images
mogrify -resize 1200x800> static/images/**/*.png
```

3. **Force rebuild:**
```bash
git commit --allow-empty -m "Force rebuild"
git push origin main
```

### If Hugo build fails:

1. **Check syntax errors:**
```bash
hugo --gc --minify --verbose 2>&1 | grep -i error
```

2. **Validate frontmatter:**
```bash
# Check all markdown files for date format
grep -r "date.*:" content/
```

3. **Clean and rebuild:**
```bash
rm -rf public/
hugo --gc --minify
```

## 📞 Support Checklist

Before asking for help, verify:

- [ ] GitHub Pages Source = "GitHub Actions"
- [ ] .nojekyll file exists
- [ ] Hugo build works locally
- [ ] No large files (>25MB)
- [ ] No problematic filenames
- [ ] Recent workflow completed successfully
- [ ] All images are in static/images/ directory

## 🎉 Expected Results

After following this guide:
- ✅ Website accessible at GitHub Pages URL
- ✅ All images loading correctly
- ✅ Hugo shortcodes working
- ✅ No Jekyll-related errors
- ✅ Fast page load times
