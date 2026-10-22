const fs = require('fs').promises;
const path = require('path');
const sharp = require('sharp');

/**
 * კონვერტაცია PNG/JPG -> WebP და ფაილების მანიპულაცია
 * @param {string} dir დირექტორიის გზა
 */
async function pngToWebp(dir) {
    try {
        const fileList = await fs.readdir(dir);
        // ნატურალური სორტირება
        fileList.sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' }));

        for (const file of fileList) {
            if (file === '.' || file === '..') continue;

            const fullPath = path.join(dir, file);
            const stat = await fs.lstat(fullPath);

            if (stat.isFile()) {
                const ext = path.extname(file).toLowerCase().replace('.', '');
                const fileNameNoExt = path.parse(file).name;

                if (['png', 'jpg', 'jpeg'].includes(ext)) {
                    console.log(`მუშავდება: ${fileNameNoExt}.${ext}`);

                    const outputPath = path.join(dir, `${fileNameNoExt}.webp`);

                    let quality = 80;
                    // if (fullPath.includes('/Spine/') || fullPath.includes('/Sprite/')) {
                    //     quality = 30; // Spine-ისთვის ოდნავ ნაკლები
                    // }

                    try {
                        await sharp(fullPath)
                            .webp({
                                quality: quality,
                                effort: 6,
                                lossless: false // თუ გინდა მაქსიმალური დაზოგვა MB-ში
                            })
                            .toFile(outputPath);
                        await fs.unlink(fullPath);
                        console.log(`წარმატებით დაკონვერტირდა: ${outputPath}`);
                    } catch (err) {
                        console.error(`შეცდომა სურათზე ${file}:`, err.message);
                    }

                } else if (ext === 'json') {
                    const content = await fs.readFile(fullPath, 'utf8');
                    const newContent = content
                        .replace(/\.png/g, '.webp')
                        .replace(/\.jpg/g, '.webp')
                        .replace(/\.jpeg/g, '.webp')
                        //.replace(/\.json/g, '.webp.json');

                    const newPath = path.join(dir, `${fileNameNoExt}.json`);
                    await fs.writeFile(newPath, newContent);
                    //await fs.unlink(fullPath);
                } else if (ext === 'atlas' || ext === 'txt') {
                    const content = await fs.readFile(fullPath, 'utf8');
                    const newContent = content
                        .replace(/\.png/g, '.webp')
                        .replace(/\.jpg/g, '.webp')
                        .replace(/\.jpeg/g, '.webp');

                    const newPath = path.join(dir, `${fileNameNoExt}.${ext}`);
                    await fs.writeFile(newPath, newContent);
                    //await fs.unlink(fullPath);
                }

            } else if (stat.isDirectory()) {
                await pngToWebp(fullPath);
            }
        }
    } catch (err) {
        console.error(`შეცდომა: ${err.message}`);
    }
}

// გაშვება
pngToWebp('assets_webp');
