using Images
using ImageView
using ProgressMeter

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
    next_element_dir = zeros(Int, size(energy_of_image))
    
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
            seam_paths[i, j] = energy_of_lowest_energy_path + energy_of_image[i, j]

            #Update the direction matrix (left = -1, down = 0, right = 1). This helps since it tells us if the 
            #   column has to reduce by one (left), stay the same (down) or increase by one (right)
            next_element_dir[i, j] = next_dir - 2 

            #Catch the case in which we are at the left edge
            if left == 1
                #We add 1 since we take the min over only two elements so we need [1,2] -> [0, 1] instead of [1, 2] -> [-1, 0]
                #   This is not a problem with the right edge as in that case [1, 2] -> [-1, 0] which is still correct
                next_element_dir[i, j] += 1
            end
        end
    end

    #Return the two matricies
    return seam_paths, next_element_dir    
end

#Get the seam starting at a pixel in the top row 
function get_seam(next_element_dir, start_column::Int)
    #Making sure we have a valid column index
    @assert (start_column <= size(next_element_dir)[2]) && (start_column >= 1) "Not a valid column index"

    #Init the seam
    seam = zeros(Int, size(next_element_dir)[1])

    #Setting the first element
    seam[1] = start_column

    #Iterate over the rest of the rows
    for i in 2:length(seam)
        seam[i] = seam[i-1] + next_element_dir[i-1, seam[i-1]]
    end

    return seam
end

#Get the seam at the best starting column
function get_seam(energy_of_image)
    #Get the values from the find_seam_paths function
    seam_paths, next_element_dir = find_seam_paths(energy_of_image)

    #Get the best starting index
    _, start_column = findmin(seam_paths[1, :])

    #Start the seam at that point
    return get_seam(next_element_dir, start_column)
end

#function that removes the seam from the image
function remove_seam(img, seam)
    #We remove one pixel from each row
    final_size = (size(img)[1], size(img)[2]-1)

    #Preallocate space
    result_img = Array{RGB{N0f8}}(undef, final_size)

    #Iterate over the seam
    for i in eachindex(seam)
        if seam[i] > 1 && seam[i] < size(img)[2]
            #Add the whole row without the pixel in the seam
            result_img[i, :] = vcat(img[i, 1:seam[i]- 1], img[i, seam[i] + 1:end])

        elseif seam[i] == 1
            #Start from the second column
            result_img[i, :] = img[i, 2:end]
        elseif seam[i] == size(img)[2]
            #Added everything except the last element
            result_img[i, :] = img[i, 1: end - 1]
        end
    end

    #Return the image that was created
    return result_img
end

#The function that does seam carving over the columns
function seam_carving_over_columns(img, final_res)
    #Check that the resolution is possible
    @assert final_res <= size(img)[2] && final_res > 0 "Resolution not valid"

    #Iterate (size(img)[2] - final_res) number of times
    @showprogress dt=1 desc="Removing seams... " for _ in 1:size(img)[2] - final_res
        #Get the energy image
        energy_of_image = find_energy(img)
        #Get the best seam
        seam = get_seam(energy_of_image)
        #Remove that seam
        img = remove_seam(img, seam)
    end

    #Return the last image
    return img
end

#Seam carving over the rows
function seam_carving_over_rows(img, final_res)
    #Check that the resolution is possible
    @assert final_res <= size(img)[1] && final_res > 0 "Resolution not valid"

    #Take the transpose
    img_T = transpose(img)

    #Run over the columns of the transpose
    img_T = seam_carving_over_columns(img_T, final_res)

    #Take the transpose again to get the original
    return transpose(img_T)
end

#A function that shows the location of the seam on the image
function display_seam(img, seam)
    #Make a copy to the original image
    display_img = copy(img)

    #Iterate over the rows of pixels
    for i in 1:size(img)[1]
        #Change the colour of the i-th rows and the corresponding column in the seam
        display_img[i, seam[i]] = RGB(1, 0, 0)
    end

    #Return the image
    return display_img
end

#A function to save a given image
function save_image(img, file_name = "image")
    save(file_name * ".png", img)
end

#Testing 
img = load("Tower.png")
println("Size of the image: ", size(img))

#Original Image
# imshow(img)

#Energy of the image
energy = find_energy(img)
# imshow(find_energy(img))

#Show the seam seam paths
seam_paths, next_element_dir = find_seam_paths(energy)
# imshow(seam_paths .* RGB(0.05, 0, 0.05))

#Show the next_element_dir
# imshow(next_element_dir)

#Show the seam with lowest energy starting from the 800 column
seam = get_seam(next_element_dir, 800)
img2 = display_seam(img, seam)
# imshow(img2)

#Finding and plotting the best seam
best_seam = get_seam(energy)
img3 = display_seam(img, seam)
# imshow(img3)

#Reduce the number of columns
img4 = seam_carving_over_columns(img, 900)
img5 = seam_carving_over_rows(img, 600)

println("Size of final image over columns ", size(img4))
println("Size of final image over rows ", size(img5))

#Compare the images
imshow(img)
imshow(img4)
imshow(img5)

#Making sure everything is done
println("Done")