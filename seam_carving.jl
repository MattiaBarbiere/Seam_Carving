using Images
using ImageView

#A function that shows the location of the seam on the image
function display_seam(img, seam)
    #Make a copy to the original image
    display_img = copy(img)

    #Iterate over the rows of pixels
    for i in 1:size(img)[i]
        #Change the colour of the i-th rows and the corresponding column in the seam
        display_img[i, seam[i]] = RGB(1, 0.34, 0.2)
    end

    #Return the image
    return display_img
end

#A function that calculates the average brightness of a pixel
function brightness_of_pix(pixel::AbstractRGB)
    return sum([pixel.r, pixel.g, pixel.b])/3
end

#This function finds the energy of an image. The energy is the importance of a pixel in the image
#Here I will use that the edges of the picture have very high energy, hence the algorithm will
#   find a seam that crosses as few edges of the image as possible
function find_energy(img)
    energy_x = imfilter(brightness_of_pix.(img), Kernel.sobel()[2])
    energy_y = imfilter(brightness_of_pix.(img), Kernel.sobel()[1])

    return sqrt.(energy_x.^2 + energy_y.^2)    
end

#Using dynamic programming we can calculate the lowest energy seam path from each pixel
function find_seam_paths(energy_of_image)
    #Init the final result
    seam_paths = zeros(size(energy_of_image))

    #To start the dynamic programming we set the last row equal to the energy of that row
    seam_paths[end, :] = energy_of_image[end, :]

    #Init the matrix that contains the direction of the lowest energy seam from each pixel
    next_element_dir = zeros(Int64, size(energy_of_image))

    #Dynamic programming step. We iterate from the bottom to the top starting from the second row
    for i in size(energy_of_image)[1]-1:-1:1
        #Iterate over columns
        for j in 1:size(energy_of_image)[2]
            #At each pixel the path can go down, left by one, right by one
            #The max and min are used for the edges of the image
            left = max(1, j-1)
            right = min(size(energy_of_image)[2], j+1)

            #Get the minimum amoung down, left, right (so that we slowly construct the path of lowest energy)
            energy_of_lowest_energy_path, next_dir = findmin(seam_paths[i+1, [left, j, right]])

            #Update the seam_paths matrix. The energy of the lowest energy path from the pixel plus the energy of the pixel
            seam_paths[i, j] = energy_of_shortest_path + energy_of_image[i, j]

            #Update the direction matrix (left = -1, down = 0, right = 1). This helps since it tells us if the 
            #   column has to reduce by one (left), stay the same (down) or increase by one (right)
            next_element_dir = next_dir - 2 

            #Catch the case in which we are at the left edge
            if left == 1
                #We add 1 since we take the min over only two elements so we need [1,2] -> [0, 1] instead of [1, 2] -> [-1, 0]
                #   This is not a problem with the right edge as in that case [1, 2] -> [-1, 0] which is still valid
                next_element_dir[i, j] += 1
            end
        end
    end


    
end

#A function to save a given image
function save_image(img, file_name = "image")
    save(file_name * ".png", img)
end

#Testing 
img = load("Tower.png")

#Original Image
# imshow(img)

#Energy of the image
# imshow(find_energy(img))

println("Done")