interface SaveData {
  save(data: string): void;
}

class SaveToS3 implements SaveData {
  save(data: string): void {
    console.log('Save to S3');
  }
}

class SaveToFile implements SaveData {
  save(data: string): void {
    console.log('Save to file');
  }
}
