import matplotlib.pyplot as plt
import tensorflow as tf
import seaborn as sns
import numpy as np
import struct

from sklearn.metrics import classification_report

from tensorflow.keras import layers
from tensorflow.keras import models

from keras import backend as K
from keras.preprocessing.image import ImageDataGenerator
from keras.preprocessing.image import load_img
from keras.preprocessing.image import img_to_array
from keras.backend import expand_dims

# dimensions of our images.
img_width, img_height = 28, 28

train_data_dir = 'D:\\Storage\\Datasets\\voice\\images\\extracted\\train'
validation_data_dir = 'D:\\Storage\\Datasets\\voice\\images\\extracted\\test'
nb_train_samples = 3277
nb_validation_samples = 2096
epochs = 50
batch_size = 300

if K.image_data_format() == 'channels_first':
    input_shape = (1, img_width, img_height)
else:
    input_shape = (img_width, img_height, 1)

model = models.Sequential([
    layers.Input(shape=input_shape),
    layers.Conv2D(32, 3, activation='relu'),
    layers.Conv2D(64, 3, activation='relu'),
    layers.MaxPooling2D(),
    layers.Dropout(0.25),
    layers.Flatten(),
    layers.Dense(100, activation='relu'),
    layers.Dropout(0.5),
    layers.Dense(10, activation='softmax'),
])

if 0:
    model.compile(loss='categorical_crossentropy',
                  optimizer='adam',
                  metrics=['accuracy'])
    
    # this is the augmentation configuration we will use for training
    train_datagen = ImageDataGenerator(
        #brightness_range=[-0.1, 0.1],
        rescale=1./255)
    
    # this is the augmentation configuration we will use for testing:
    test_datagen = ImageDataGenerator(
        #brightness_range=[-0.1, 0.1],
        rescale=1./255)
    
    train_generator = train_datagen.flow_from_directory(
        train_data_dir,
        target_size=(img_width, img_height),
        color_mode='grayscale',
        batch_size=batch_size)
    
    validation_generator = test_datagen.flow_from_directory(
        validation_data_dir,
        target_size=(img_width, img_height),
        color_mode='grayscale',
        batch_size=batch_size,
        shuffle=False)
    
    history = model.fit_generator(
        train_generator,
        steps_per_epoch=nb_train_samples // batch_size,
        epochs=epochs,
        validation_data=validation_generator,
        validation_steps=nb_validation_samples // batch_size)
    
    # graphs
    metrics = history.history
    plt.plot(history.epoch, metrics['loss'], metrics['val_loss'])
    plt.legend(['loss', 'val_loss'])
    plt.show()
    
    Y_pred = model.predict_generator(validation_generator, nb_validation_samples // batch_size+1)
    y_pred = np.argmax(Y_pred, axis=1)
    
    class_labels = list(validation_generator.class_indices.keys())   
    
    # more graphs
    confusion_mtx = tf.math.confusion_matrix(validation_generator.classes, y_pred) 
    plt.figure(figsize=(10, 8))
    sns.heatmap(confusion_mtx, xticklabels=class_labels, yticklabels=class_labels, 
                annot=True, fmt='g')
    plt.xlabel('Prediction')
    plt.ylabel('Label')
    plt.show()
    
    #stats
    print('Classification Report')
    print(classification_report(validation_generator.classes, y_pred, target_names=class_labels))
    
    model.save_weights('VoiceNetwork.h5')
else:
    model.load_weights('VoiceNetwork.h5')

weights = model.get_weights()

dest = "voice.bytes"

#ouput byte file for C++ and Unity
def write_weights4(array, mode='ab'):
    with open(dest, mode) as f:
        for i in range(0, len(array)):
            for j in range(0, len(array[0])):
                for k in range(0, len(array[0][0])):
                    for l in range(0, len(array[0][0][0])):
                        f.write(struct.pack('f', array[i][j][k][l]))
        f.close()

def write_weights2(array, mode='ab'):
    with open(dest, mode) as f:
        for i in range(0, len(array)):
            for j in range(0, len(array[0])):
                f.write(struct.pack('f', array[i][j]))
        f.close()
                
                
def write_bias(array):
    with open(dest, 'ab') as f:
        for i in range(0, len(array)):
            f.write(struct.pack('f', array[i]))
        f.close()
        
write_weights4(weights[0], 'wb')
write_bias(weights[1])
write_weights4(weights[2])
write_bias(weights[3])
write_weights2(weights[4])
write_bias(weights[5])
write_weights2(weights[6])
write_bias(weights[7])

# Predict
img = load_img('D:\\Storage\\Datasets\\voice\\images\\extracted\\test\\sit\\sit1-550.png')
# convert to numpy array
img_np = img_to_array(img) / 255.
new_image = expand_dims(img_np[:,:,0], 0)

#debugging
outputs = [K.function([model.input], [layer.output])([new_image, 1]) for layer in model.layers]